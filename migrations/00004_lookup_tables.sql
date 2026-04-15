-- +goose Up

CREATE TABLE lookup.lead_sources (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    account_id      UUID NOT NULL REFERENCES core.accounts(id) ON DELETE CASCADE,
    name            TEXT NOT NULL,
    is_active       BOOLEAN DEFAULT true,
    created_at      TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE lookup.services_catalogue (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    account_id      UUID NOT NULL REFERENCES core.accounts(id) ON DELETE CASCADE,
    name            TEXT NOT NULL,
    category        TEXT,
    default_price   NUMERIC(10,2),
    is_active       BOOLEAN DEFAULT true,
    created_at      TIMESTAMPTZ DEFAULT now(),
    updated_at      TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE lookup.products_catalogue (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    account_id      UUID NOT NULL REFERENCES core.accounts(id) ON DELETE CASCADE,
    name            TEXT NOT NULL,
    category        TEXT,
    unit            TEXT,
    is_active       BOOLEAN DEFAULT true,
    created_at      TIMESTAMPTZ DEFAULT now(),
    updated_at      TIMESTAMPTZ DEFAULT now()
);

-- +goose Down

DROP TABLE IF EXISTS lookup.products_catalogue;
DROP TABLE IF EXISTS lookup.services_catalogue;
DROP TABLE IF EXISTS lookup.lead_sources;