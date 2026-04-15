-- +goose Up

CREATE TABLE audit.lead_activity (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    lead_id         UUID NOT NULL REFERENCES core.leads(id) ON DELETE CASCADE,
    changed_by      UUID REFERENCES core.users(id),
    old_status      TEXT,
    new_status      TEXT,
    note            TEXT,
    created_at      TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE audit.stock_logs (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    inventory_id    UUID NOT NULL REFERENCES core.inventory(id) ON DELETE CASCADE,
    type            TEXT NOT NULL CHECK (type IN ('stock_in', 'stock_out', 'adjustment')),
    quantity        NUMERIC(10,2) NOT NULL,
    reference       TEXT,
    logged_by       UUID REFERENCES core.users(id),
    created_at      TIMESTAMPTZ DEFAULT now()
);

-- +goose Down

DROP TABLE IF EXISTS audit.stock_logs;
DROP TABLE IF EXISTS audit.lead_activity;