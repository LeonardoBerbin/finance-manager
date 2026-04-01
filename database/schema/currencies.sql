-- SCHEMA: Currencies and Exchange Rates (database/scheme/currencies.sql)
---------------------------------------------------------------------------------------------------------

-- RESET SCHEMA

DROP TABLE IF EXISTS exchange_rates CASCADE;
DROP TABLE IF EXISTS currencies CASCADE;

-- CREATE SCHEMA

CREATE TABLE currencies (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code CHAR(3) NOT NULL UNIQUE,
    name VARCHAR(255) NOT NULL,
    enabled BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT code_format CHECK (code ~ '^[A-Z]{3}$')
);

ALTER TABLE currencies ENABLE ROW LEVEL SECURITY;

COMMENT ON TABLE currencies IS
'List of supported fiat currencies (ISO 4217)';

COMMENT ON COLUMN currencies.code IS
'Three-letter ISO currency code (e.g., USD, EUR, COP)';

CREATE TRIGGER update_currency_timestamp
BEFORE UPDATE ON currencies
FOR EACH ROW
EXECUTE FUNCTION update_timestamp();

CREATE TABLE exchange_rates (
    base_currency_id UUID REFERENCES currencies(id) ON DELETE RESTRICT NOT NULL,
    target_currency_id UUID REFERENCES currencies(id) ON DELETE RESTRICT NOT NULL,
    rate NUMERIC(12, 6) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT exchange_rates_pkey PRIMARY KEY (base_currency_id, target_currency_id),
    CONSTRAINT exchange_rates_check CHECK (base_currency_id <> target_currency_id),
    CONSTRAINT exchange_rates_rate_positive CHECK (rate > 0)
);

ALTER TABLE exchange_rates ENABLE ROW LEVEL SECURITY;

COMMENT ON TABLE exchange_rates IS
'Reference exchange rates between currencies (non-historical, informational only)';

COMMENT ON COLUMN exchange_rates.base_currency_id IS
'Source currency in the exchange rate pair';

COMMENT ON COLUMN exchange_rates.target_currency_id IS
'Target currency in the exchange rate pair';

CREATE INDEX idx_exchange_rate_target_to_base 
ON exchange_rates (target_currency_id, base_currency_id);

COMMENT ON INDEX idx_exchange_rate_target_to_base IS
'Supports efficient reverse lookup of exchange rates (target to base)';

CREATE TRIGGER update_exchange_rate_timestamp
BEFORE UPDATE ON exchange_rates
FOR EACH ROW
EXECUTE FUNCTION update_timestamp();