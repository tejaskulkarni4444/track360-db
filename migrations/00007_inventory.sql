-- +goose Up

CREATE TABLE core.inventory (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    location_id         UUID NOT NULL REFERENCES core.locations(id) ON DELETE CASCADE,
    product_id          UUID NOT NULL REFERENCES lookup.products_catalogue(id),
    current_stock       NUMERIC(10,2) NOT NULL DEFAULT 0,
    reorder_threshold   NUMERIC(10,2) NOT NULL DEFAULT 0,
    cost_per_unit       NUMERIC(10,2),
    supplier_name       TEXT,
    updated_at          TIMESTAMPTZ DEFAULT now(),
    UNIQUE (location_id, product_id)
);

-- +goose Down

DROP TABLE IF EXISTS core.inventory;