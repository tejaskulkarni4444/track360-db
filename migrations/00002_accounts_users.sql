-- +goose Up

CREATE TABLE core.accounts (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name            TEXT NOT NULL,
    is_active       BOOLEAN DEFAULT true,
    created_at      TIMESTAMPTZ DEFAULT now(),
    updated_at      TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE core.users (
    id              UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    account_id      UUID REFERENCES core.accounts(id) ON DELETE CASCADE,
    full_name       TEXT NOT NULL,
    phone           TEXT,
    is_owner        BOOLEAN DEFAULT false,
    is_active       BOOLEAN DEFAULT true,
    created_at      TIMESTAMPTZ DEFAULT now(),
    updated_at      TIMESTAMPTZ DEFAULT now()
);

-- +goose Down

DROP TABLE IF EXISTS core.users;
DROP TABLE IF EXISTS core.accounts;