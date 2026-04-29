---------------------------------------------------------------------------------------------------------
-- RESET SCHEMA
---------------------------------------------------------------------------------------------------------

DROP TABLE IF EXISTS exchange_rates CASCADE;
DROP TABLE IF EXISTS currencies CASCADE;

---------------------------------------------------------------------------------------------------------
-- CURRENCIES DEFINITION
---------------------------------------------------------------------------------------------------------

CREATE TABLE currencies (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code CHAR(3) NOT NULL UNIQUE,
    label VARCHAR(255) NOT NULL,
    enabled BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_currency_label_not_blank CHECK (length(trim(label)) > 0),
    CONSTRAINT chk_currency_code_format CHECK (code ~ '^[A-Z]{3}$')
);

ALTER TABLE currencies ENABLE ROW LEVEL SECURITY;

COMMENT ON TABLE currencies IS 'Supported fiat currencies based on ISO 4217 standard (e.g., USD, EUR, COP).';
COMMENT ON COLUMN currencies.code IS 'Three-letter ISO 4217 currency code used as stable identifier (e.g., USD, EUR, COP).';
COMMENT ON COLUMN currencies.label IS 'Human-readable currency name (e.g., US Dollar, Euro).';
COMMENT ON COLUMN currencies.enabled IS 'Indicates whether the currency is available for use in the system.';

CREATE TRIGGER update_currency_timestamp
BEFORE UPDATE ON currencies
FOR EACH ROW
EXECUTE FUNCTION update_timestamp();

---------------------------------------------------------------------------------------------------------
-- EXCHANGE RATES DEFINITION
---------------------------------------------------------------------------------------------------------

CREATE TABLE exchange_rates (
    base_currency_id UUID REFERENCES currencies(id) ON DELETE RESTRICT NOT NULL,
    target_currency_id UUID REFERENCES currencies(id) ON DELETE RESTRICT NOT NULL,

    rate NUMERIC(18, 8) NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT pk_exchange_rates PRIMARY KEY (base_currency_id, target_currency_id),
    CONSTRAINT chk_no_self_exchange CHECK (base_currency_id <> target_currency_id),
    CONSTRAINT chk_rate_positive CHECK (rate > 0)
);

ALTER TABLE exchange_rates ENABLE ROW LEVEL SECURITY;

COMMENT ON TABLE exchange_rates IS 'Latest exchange rates between currencies. This table stores current rates only (not historical data).';
COMMENT ON COLUMN exchange_rates.base_currency_id IS 'Source currency in the exchange pair (from currency).';
COMMENT ON COLUMN exchange_rates.target_currency_id IS 'Destination currency in the exchange pair (to currency).';
COMMENT ON COLUMN exchange_rates.rate IS 'Conversion rate from base currency to target currency at last update.';

CREATE INDEX idx_exchange_rates_base_target ON exchange_rates (base_currency_id, target_currency_id);
CREATE INDEX idx_exchange_rates_target_base ON exchange_rates (target_currency_id, base_currency_id);

CREATE TRIGGER update_exchange_rate_timestamp
BEFORE UPDATE ON exchange_rates
FOR EACH ROW
EXECUTE FUNCTION update_timestamp();