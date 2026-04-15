-- +goose Up

CREATE TABLE core.leads (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    location_id         UUID NOT NULL REFERENCES core.locations(id) ON DELETE CASCADE,
    full_name           TEXT NOT NULL,
    phone               TEXT NOT NULL,
    source_id           UUID REFERENCES lookup.lead_sources(id),
    status              TEXT NOT NULL DEFAULT 'new' CHECK (status IN (
                            'new', 'contacted', 'consultation_booked', 'converted', 'lost'
                        )),
    service_interest_id UUID REFERENCES lookup.services_catalogue(id),
    assigned_to         UUID REFERENCES core.users(id),
    follow_up_date      DATE,
    notes               TEXT,
    created_at          TIMESTAMPTZ DEFAULT now(),
    updated_at          TIMESTAMPTZ DEFAULT now()
);

-- +goose Down

DROP TABLE IF EXISTS core.leads;