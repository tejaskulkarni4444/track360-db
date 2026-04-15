-- +goose Up

CREATE TABLE core.transactions (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    location_id     UUID NOT NULL REFERENCES core.locations(id) ON DELETE CASCADE,
    lead_id         UUID REFERENCES core.leads(id) ON DELETE SET NULL,
    client_name     TEXT NOT NULL,
    service_id      UUID REFERENCES lookup.services_catalogue(id),
    amount          NUMERIC(10,2) NOT NULL,
    discount        NUMERIC(10,2) DEFAULT 0,
    final_amount    NUMERIC(10,2) NOT NULL,
    payment_mode    TEXT CHECK (payment_mode IN (
                        'cash', 'upi', 'card', 'emi', 'other'
                    )),
    payment_status  TEXT NOT NULL DEFAULT 'paid' CHECK (payment_status IN (
                        'paid', 'partial', 'pending'
                    )),
    delivered_by    UUID REFERENCES core.users(id),
    created_by      UUID REFERENCES core.users(id),
    transaction_date DATE NOT NULL,
    notes           TEXT,
    created_at      TIMESTAMPTZ DEFAULT now(),
    updated_at      TIMESTAMPTZ DEFAULT now()
);

-- +goose Down

DROP TABLE IF EXISTS core.transactions;