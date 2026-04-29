---------------------------------------------------------------------------------------------------------
-- RESET SCHEMA
---------------------------------------------------------------------------------------------------------

DROP TYPE IF EXISTS cost_types;
DROP TYPE IF EXISTS value_types;

DROP TABLE IF EXISTS account_settings CASCADE;
DROP TABLE IF EXISTS accounts CASCADE;
DROP TABLE IF EXISTS account_types CASCADE;

---------------------------------------------------------------------------------------------------------
-- ACCOUNT TYPES DEFINITION
---------------------------------------------------------------------------------------------------------

CREATE TABLE account_types (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL UNIQUE,
    label VARCHAR(100) NOT NULL,
    version INT NOT NULL DEFAULT 1,
    enabled BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_account_types_code_not_blank CHECK (length(trim(code)) > 0),
    CONSTRAINT chk_account_types_label_not_blank CHECK (length(trim(label)) > 0),
    CONSTRAINT chk_account_types_version_positive CHECK (version > 0)
);

ALTER TABLE account_types ENABLE ROW LEVEL SECURITY;

COMMENT ON TABLE account_types IS 'Defines the catalog of account types used to classify account behavior in the system.';
COMMENT ON COLUMN account_types.code IS 'Internal unique identifier used by backend logic to determine account behavior.';
COMMENT ON COLUMN account_types.label IS 'Human-readable name for UI display.';
COMMENT ON COLUMN account_types.version IS 'Version of the account type definition used to evolve behavior without breaking existing accounts.';

CREATE TRIGGER update_account_types_timestamp
BEFORE UPDATE ON account_types
FOR EACH ROW
EXECUTE FUNCTION update_timestamp();

---------------------------------------------------------------------------------------------------------
-- ACCOUNTS DEFINITION
---------------------------------------------------------------------------------------------------------

CREATE TYPE cost_types AS ENUM ('fixed', 'percentage');

CREATE TABLE accounts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
    currency_id UUID REFERENCES currencies(id) ON DELETE RESTRICT NOT NULL,
    type_id UUID REFERENCES account_types(id) ON DELETE RESTRICT NOT NULL,
    name VARCHAR(255) NOT NULL,
    balance NUMERIC(36, 2) NOT NULL DEFAULT 0.00,
    block_balance NUMERIC(36, 2) NOT NULL DEFAULT 0.00,
    allow_negative_balance BOOLEAN NOT NULL DEFAULT FALSE,
    cost_per_transaction_type cost_types NOT NULL DEFAULT 'fixed',
    cost_per_transaction NUMERIC(12, 6) NOT NULL DEFAULT 0.00,
    enabled BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_accounts_name_not_blank CHECK (length(trim(name)) > 0),
    CONSTRAINT chk_accounts_balance_non_negative CHECK (allow_negative_balance OR balance >= 0),
    CONSTRAINT chk_accounts_block_balance_non_negative CHECK (block_balance >= 0),
    CONSTRAINT chk_accounts_cost_non_negative CHECK (cost_per_transaction >= 0)
);

ALTER TABLE accounts ENABLE ROW LEVEL SECURITY;

COMMENT ON TABLE accounts IS 'Represents financial accounts belonging to users, including cash, credit, investment and loan structures.';
COMMENT ON COLUMN accounts.user_id IS 'Owner of the account.';
COMMENT ON COLUMN accounts.currency_id IS 'Currency in which the account is denominated.';
COMMENT ON COLUMN accounts.type_id IS 'Reference to account_types defining behavioral rules for the account.';
COMMENT ON COLUMN accounts.name IS 'User-defined name for the account.';
COMMENT ON COLUMN accounts.balance IS 'Available balance in the account.';
COMMENT ON COLUMN accounts.block_balance IS 'Funds reserved or blocked from use.';
COMMENT ON COLUMN accounts.allow_negative_balance IS 'Indicates whether the account can go into negative balance.';
COMMENT ON COLUMN accounts.cost_per_transaction IS 'Cost applied per transaction depending on account configuration.';
COMMENT ON COLUMN accounts.cost_per_transaction_type IS 'Defines whether transaction cost is fixed or percentage-based.';

CREATE INDEX idx_accounts_user_id ON accounts (user_id);
CREATE INDEX idx_accounts_user_enabled ON accounts (user_id, enabled);
CREATE INDEX idx_accounts_type_per_user_id ON accounts (user_id, type_id);

CREATE TRIGGER update_accounts_timestamp
BEFORE UPDATE ON accounts
FOR EACH ROW
EXECUTE FUNCTION update_timestamp();

---------------------------------------------------------------------------------------------------------
-- ACCOUNT SETTINGS DEFINITION
---------------------------------------------------------------------------------------------------------

CREATE TYPE value_types AS ENUM ('string', 'double', 'int', 'boolean', 'date');

CREATE TABLE account_settings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    account_id UUID REFERENCES accounts(id) ON DELETE CASCADE NOT NULL,
    key VARCHAR(255) NOT NULL,
    value TEXT NOT NULL,
    value_type value_types NOT NULL DEFAULT 'string',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_account_settings_key_not_blank CHECK (length(trim(key)) > 0),
    CONSTRAINT chk_account_settings_value_not_blank CHECK (length(trim(value)) > 0),
    CONSTRAINT chk_account_settings_value_length CHECK (length(value) <= 2000),
    CONSTRAINT uq_account_settings_account_key UNIQUE (account_id, key),
    CONSTRAINT chk_account_settings_type_valid_string 
        CHECK (
            (value_type = 'string') OR
            (value_type = 'int' AND value ~ '^-?\d+$') OR
            (value_type = 'double' AND value ~ '^-?\d+(\.\d+)?$') OR
            (value_type = 'boolean' AND lower(value) IN ('true','false')) OR
            (value_type = 'date' AND value ~ '^\d{4}-\d{2}-\d{2}')
        )
);

COMMENT ON TABLE account_settings IS 'Flexible key-value configuration system for extending account behavior without schema changes.';
COMMENT ON COLUMN account_settings.account_id IS 'Reference to the account this setting belongs to.';
COMMENT ON COLUMN account_settings.key IS 'Configuration key name (e.g. interest_rate, limit, lock_period).';
COMMENT ON COLUMN account_settings.value IS 'Raw stored value interpreted according to value_type.';
COMMENT ON COLUMN account_settings.value_type IS 'Defines how the value should be parsed and validated.';

CREATE INDEX idx_account_settings_account_id ON account_settings (account_id);

CREATE TRIGGER update_account_settings_timestamp
BEFORE UPDATE ON account_settings
FOR EACH ROW
EXECUTE FUNCTION update_timestamp();