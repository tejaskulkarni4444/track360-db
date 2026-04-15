-- +goose Up

-- ============================================================
-- HELPER FUNCTIONS
-- ============================================================

-- Get the account_id for the currently logged in user
CREATE OR REPLACE FUNCTION core.get_account_id()
RETURNS UUID AS $$
  SELECT account_id FROM core.users WHERE id = auth.uid();
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- Get the role of the current user at a specific location
CREATE OR REPLACE FUNCTION core.get_user_role(p_location_id UUID)
RETURNS TEXT AS $$
  SELECT role FROM core.location_staff
  WHERE profile_id = auth.uid()
  AND location_id = p_location_id
  AND is_active = true;
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- Check if current user is an owner
CREATE OR REPLACE FUNCTION core.is_owner()
RETURNS BOOLEAN AS $$
  SELECT is_owner FROM core.users WHERE id = auth.uid();
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- Check if current user is platform admin
CREATE OR REPLACE FUNCTION platform.is_platform_admin()
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM platform.platform_admins WHERE id = auth.uid()
  );
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- Check if current user has access to a location
CREATE OR REPLACE FUNCTION core.has_location_access(p_location_id UUID)
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM core.location_staff
    WHERE profile_id = auth.uid()
    AND location_id = p_location_id
    AND is_active = true
  );
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- ============================================================
-- ENABLE RLS ON ALL TABLES
-- ============================================================

ALTER TABLE core.accounts         ENABLE ROW LEVEL SECURITY;
ALTER TABLE core.users            ENABLE ROW LEVEL SECURITY;
ALTER TABLE core.locations        ENABLE ROW LEVEL SECURITY;
ALTER TABLE core.location_staff   ENABLE ROW LEVEL SECURITY;
ALTER TABLE core.leads            ENABLE ROW LEVEL SECURITY;
ALTER TABLE core.transactions     ENABLE ROW LEVEL SECURITY;
ALTER TABLE core.inventory        ENABLE ROW LEVEL SECURITY;
ALTER TABLE lookup.lead_sources         ENABLE ROW LEVEL SECURITY;
ALTER TABLE lookup.services_catalogue   ENABLE ROW LEVEL SECURITY;
ALTER TABLE lookup.products_catalogue   ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit.lead_activity   ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit.stock_logs      ENABLE ROW LEVEL SECURITY;

-- ============================================================
-- core.accounts
-- ============================================================

-- Anyone in the account can read
CREATE POLICY accounts_read ON core.accounts
  FOR SELECT USING (
    id = core.get_account_id()
    OR platform.is_platform_admin()
  );

-- Only owner or platform admin can update
CREATE POLICY accounts_update ON core.accounts
  FOR UPDATE USING (
    id = core.get_account_id() AND core.is_owner()
    OR platform.is_platform_admin()
  );

-- ============================================================
-- core.users
-- ============================================================

-- Users can read others in same account
CREATE POLICY users_read ON core.users
  FOR SELECT USING (
    account_id = core.get_account_id()
    OR platform.is_platform_admin()
  );

-- Users can update their own record only
-- Owners can update anyone in their account
CREATE POLICY users_update ON core.users
  FOR UPDATE USING (
    id = auth.uid()
    OR (core.is_owner() AND account_id = core.get_account_id())
    OR platform.is_platform_admin()
  );

-- ============================================================
-- core.locations
-- ============================================================

-- Owner sees all locations in their account
-- Staff sees only locations they are assigned to
CREATE POLICY locations_read ON core.locations
  FOR SELECT USING (
    account_id = core.get_account_id()
    AND (
      core.is_owner()
      OR core.has_location_access(id)
      OR platform.is_platform_admin()
    )
  );

-- Only owner can create/update locations
CREATE POLICY locations_write ON core.locations
  FOR ALL USING (
    account_id = core.get_account_id()
    AND core.is_owner()
    OR platform.is_platform_admin()
  );

-- ============================================================
-- core.location_staff
-- ============================================================

CREATE POLICY location_staff_read ON core.location_staff
  FOR SELECT USING (
    core.has_location_access(location_id)
    OR core.is_owner()
    OR platform.is_platform_admin()
  );

-- Only owner or admin can manage staff assignments
CREATE POLICY location_staff_write ON core.location_staff
  FOR ALL USING (
    core.is_owner()
    OR core.get_user_role(location_id) = 'admin'
    OR platform.is_platform_admin()
  );

-- ============================================================
-- lookup tables (lead_sources, services_catalogue, products_catalogue)
-- ============================================================

-- Everyone in the account can read lookup tables
CREATE POLICY lead_sources_read ON lookup.lead_sources
  FOR SELECT USING (account_id = core.get_account_id());

-- Only owner, admin, accountant can write lookup tables
CREATE POLICY lead_sources_write ON lookup.lead_sources
  FOR ALL USING (
    account_id = core.get_account_id()
    AND (
      core.is_owner()
      OR EXISTS (
        SELECT 1 FROM core.location_staff ls
        WHERE ls.profile_id = auth.uid()
        AND ls.role IN ('admin', 'accountant')
        AND ls.is_active = true
      )
    )
  );

-- Same pattern for services_catalogue
CREATE POLICY services_catalogue_read ON lookup.services_catalogue
  FOR SELECT USING (account_id = core.get_account_id());

CREATE POLICY services_catalogue_write ON lookup.services_catalogue
  FOR ALL USING (
    account_id = core.get_account_id()
    AND (
      core.is_owner()
      OR EXISTS (
        SELECT 1 FROM core.location_staff ls
        WHERE ls.profile_id = auth.uid()
        AND ls.role IN ('admin', 'accountant')
        AND ls.is_active = true
      )
    )
  );

-- Same pattern for products_catalogue
CREATE POLICY products_catalogue_read ON lookup.products_catalogue
  FOR SELECT USING (account_id = core.get_account_id());

CREATE POLICY products_catalogue_write ON lookup.products_catalogue
  FOR ALL USING (
    account_id = core.get_account_id()
    AND (
      core.is_owner()
      OR EXISTS (
        SELECT 1 FROM core.location_staff ls
        WHERE ls.profile_id = auth.uid()
        AND ls.role IN ('admin', 'accountant')
        AND ls.is_active = true
      )
    )
  );

-- ============================================================
-- core.leads
-- ============================================================

-- Owner + admin: all leads at their locations
-- Staff: all leads at their location
-- Accountant: read only
-- Specialist: only leads assigned to them
CREATE POLICY leads_read ON core.leads
  FOR SELECT USING (
    core.has_location_access(location_id)
    AND (
      core.is_owner()
      OR core.get_user_role(location_id) IN ('admin', 'staff')
      OR core.get_user_role(location_id) = 'accountant'
      OR (
        core.get_user_role(location_id) = 'specialist'
        AND assigned_to = auth.uid()
      )
    )
  );

-- Owner + admin + staff: write all leads
-- Specialist: write only assigned leads
CREATE POLICY leads_write ON core.leads
  FOR ALL USING (
    core.has_location_access(location_id)
    AND (
      core.is_owner()
      OR core.get_user_role(location_id) IN ('admin', 'staff')
      OR (
        core.get_user_role(location_id) = 'specialist'
        AND assigned_to = auth.uid()
      )
    )
  );

-- ============================================================
-- core.transactions
-- ============================================================

-- Owner + admin + accountant: all transactions
-- Specialist: only their own
-- Staff: no access
CREATE POLICY transactions_read ON core.transactions
  FOR SELECT USING (
    core.has_location_access(location_id)
    AND (
      core.is_owner()
      OR core.get_user_role(location_id) IN ('admin', 'accountant')
      OR (
        core.get_user_role(location_id) = 'specialist'
        AND delivered_by = auth.uid()
      )
    )
  );

CREATE POLICY transactions_write ON core.transactions
  FOR ALL USING (
    core.has_location_access(location_id)
    AND (
      core.is_owner()
      OR core.get_user_role(location_id) IN ('admin', 'accountant')
      OR (
        core.get_user_role(location_id) = 'specialist'
        AND delivered_by = auth.uid()
      )
    )
  );

-- ============================================================
-- core.inventory
-- ============================================================

-- Owner + admin + accountant + staff: full access
-- Specialist: read only
CREATE POLICY inventory_read ON core.inventory
  FOR SELECT USING (
    core.has_location_access(location_id)
    AND (
      core.is_owner()
      OR core.get_user_role(location_id) IN ('admin', 'accountant', 'staff', 'specialist')
    )
  );

CREATE POLICY inventory_write ON core.inventory
  FOR ALL USING (
    core.has_location_access(location_id)
    AND (
      core.is_owner()
      OR core.get_user_role(location_id) IN ('admin', 'accountant', 'staff')
    )
  );

-- ============================================================
-- audit tables
-- ============================================================

-- Read only for owner + admin + accountant
-- No direct writes (inserted programmatically by backend only)
CREATE POLICY lead_activity_read ON audit.lead_activity
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM core.leads l
      WHERE l.id = lead_id
      AND core.has_location_access(l.location_id)
      AND (
        core.is_owner()
        OR core.get_user_role(l.location_id) IN ('admin', 'accountant')
      )
    )
  );

CREATE POLICY stock_logs_read ON audit.stock_logs
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM core.inventory i
      WHERE i.id = inventory_id
      AND core.has_location_access(i.location_id)
      AND (
        core.is_owner()
        OR core.get_user_role(i.location_id) IN ('admin', 'accountant')
      )
    )
  );

-- ============================================================
-- platform.platform_admins
-- ============================================================

ALTER TABLE platform.platform_admins ENABLE ROW LEVEL SECURITY;

-- Only platform admins can see this table
CREATE POLICY platform_admins_read ON platform.platform_admins
  FOR SELECT USING (platform.is_platform_admin());

-- +goose Down

-- Drop policies
DROP POLICY IF EXISTS accounts_read ON core.accounts;
DROP POLICY IF EXISTS accounts_update ON core.accounts;
DROP POLICY IF EXISTS users_read ON core.users;
DROP POLICY IF EXISTS users_update ON core.users;
DROP POLICY IF EXISTS locations_read ON core.locations;
DROP POLICY IF EXISTS locations_write ON core.locations;
DROP POLICY IF EXISTS location_staff_read ON core.location_staff;
DROP POLICY IF EXISTS location_staff_write ON core.location_staff;
DROP POLICY IF EXISTS lead_sources_read ON lookup.lead_sources;
DROP POLICY IF EXISTS lead_sources_write ON lookup.lead_sources;
DROP POLICY IF EXISTS services_catalogue_read ON lookup.services_catalogue;
DROP POLICY IF EXISTS services_catalogue_write ON lookup.services_catalogue;
DROP POLICY IF EXISTS products_catalogue_read ON lookup.products_catalogue;
DROP POLICY IF EXISTS products_catalogue_write ON lookup.products_catalogue;
DROP POLICY IF EXISTS leads_read ON core.leads;
DROP POLICY IF EXISTS leads_write ON core.leads;
DROP POLICY IF EXISTS transactions_read ON core.transactions;
DROP POLICY IF EXISTS transactions_write ON core.transactions;
DROP POLICY IF EXISTS inventory_read ON core.inventory;
DROP POLICY IF EXISTS inventory_write ON core.inventory;
DROP POLICY IF EXISTS lead_activity_read ON audit.lead_activity;
DROP POLICY IF EXISTS stock_logs_read ON audit.stock_logs;
DROP POLICY IF EXISTS platform_admins_read ON platform.platform_admins;

-- Drop functions
DROP FUNCTION IF EXISTS core.get_account_id();
DROP FUNCTION IF EXISTS core.get_user_role(UUID);
DROP FUNCTION IF EXISTS core.is_owner();
DROP FUNCTION IF EXISTS platform.is_platform_admin();
DROP FUNCTION IF EXISTS core.has_location_access(UUID);