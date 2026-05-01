---------------------------------------------------------------------------------------------------------
-- RESET SCHEMA
---------------------------------------------------------------------------------------------------------

DROP TABLE IF EXISTS accounts CASCADE;
DROP TABLE IF EXISTS account_types CASCADE;

---------------------------------------------------------------------------------------------------------
-- ACCOUNT TYPES DEFINITION
---------------------------------------------------------------------------------------------------------

CREATE TABLE account_types (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(100) UNIQUE NOT NULL,
    label VARCHAR(255) NOT NULL,
    description TEXT,
    category VARCHAR(100) NOT NULL,
    can_pay BOOLEAN NOT NULL DEFAULT FALSE,
    can_collect BOOLEAN NOT NULL DEFAULT FALSE,
    can_transfer BOOLEAN NOT NULL DEFAULT TRUE,
    can_revalue BOOLEAN NOT NULL DEFAULT FALSE,
    metadata_definition JSONB NOT NULL DEFAULT '{}',
    enabled BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_account_types_code_not_blank CHECK (length(trim(code)) > 0),
    CONSTRAINT chk_account_types_category_not_blank CHECK (length(trim(category)) > 0),
    CONSTRAINT chk_account_types_label_not_blank CHECK (length(trim(label)) > 0),
    CONSTRAINT chk_account_types_metadata_is_object CHECK (jsonb_typeof(metadata_definition) = 'object')
);

ALTER TABLE account_types ENABLE ROW LEVEL SECURITY;

COMMENT ON TABLE account_types IS 'Defines behavioral capabilities and classification of accounts. Used by backend to enforce transaction rules.';
COMMENT ON COLUMN account_types.code IS 'Unique internal identifier for the account type (e.g., cash, credit, investment).';
COMMENT ON COLUMN account_types.category IS 'High-level classification used primarily for UI grouping (e.g., assets, liabilities, investments).';
COMMENT ON COLUMN account_types.can_pay IS 'Indicates whether accounts of this type can be used as source of funds in expenses.';
COMMENT ON COLUMN account_types.can_collect IS 'Indicates whether accounts of this type can receive funds as income.';
COMMENT ON COLUMN account_types.can_transfer IS 'Indicates whether accounts of this type can participate in internal transfers.';
COMMENT ON COLUMN account_types.can_revalue IS 'Indicates whether the account supports non-cash adjustments (e.g., asset appreciation).';
COMMENT ON COLUMN account_types.metadata_definition IS 'Backend-defined JSON contract describing allowed metadata structure for accounts of this type.';

CREATE TRIGGER update_account_types_timestamp
BEFORE UPDATE ON account_types
FOR EACH ROW
EXECUTE FUNCTION update_timestamp();

---------------------------------------------------------------------------------------------------------
-- ACCOUNTS DEFINITION
---------------------------------------------------------------------------------------------------------

CREATE TABLE accounts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
    currency_id UUID REFERENCES currencies(id) ON DELETE RESTRICT NOT NULL,
    type_id UUID REFERENCES account_types(id) ON DELETE RESTRICT NOT NULL,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    current_balance NUMERIC(36, 2) NOT NULL DEFAULT 0.00,
    reserved_balance NUMERIC(36, 2) NOT NULL DEFAULT 0.00,
    overdraft_allowance NUMERIC(36, 2) NOT NULL DEFAULT 0.00,
    available_balance NUMERIC(36, 2) GENERATED ALWAYS AS (GREATEST(current_balance - reserved_balance + overdraft_allowance, 0)) STORED,
    fixed_transaction_fee NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    percentage_transaction_fee NUMERIC(4,2) NOT NULL DEFAULT 0.00,
    metadata JSONB NOT NULL DEFAULT '{}',
    enabled BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_accounts_name_not_blank CHECK (length(trim(name)) > 0),
    CONSTRAINT uq_accounts_user_name UNIQUE (user_id, name),
    CONSTRAINT chk_accounts_current_balance_valid CHECK (current_balance >= -overdraft_allowance),
    CONSTRAINT chk_accounts_reserved_balance_valid CHECK (reserved_balance >= 0 AND reserved_balance <= current_balance + overdraft_allowance),
    CONSTRAINT chk_non_negative_values CHECK (overdraft_allowance >= 0 AND fixed_transaction_fee >= 0),
    CONSTRAINT chk_percentage_fee_range CHECK (percentage_transaction_fee >= 0 AND percentage_transaction_fee <= 100),
    CONSTRAINT chk_accounts_metadata_is_object CHECK (jsonb_typeof(metadata) = 'object')
);

ALTER TABLE accounts ENABLE ROW LEVEL SECURITY;

COMMENT ON TABLE accounts IS 'Represents user financial accounts with balance tracking, credit capacity, and operational constraints.';
COMMENT ON COLUMN accounts.current_balance IS 'Actual balance of the account. Can be negative within overdraft limits.';
COMMENT ON COLUMN accounts.reserved_balance IS 'Amount committed or reserved, reducing available funds. Can consume overdraft capacity.';
COMMENT ON COLUMN accounts.overdraft_allowance IS 'Maximum negative balance allowed for the account. Defines credit capacity.';
COMMENT ON COLUMN accounts.available_balance IS 'Computed available funds considering balance, reservations, and overdraft. Never negative.';
COMMENT ON COLUMN accounts.fixed_transaction_fee IS 'Flat fee applied per transaction when applicable.';
COMMENT ON COLUMN accounts.percentage_transaction_fee IS 'Percentage fee applied per transaction (0–100).';
COMMENT ON COLUMN accounts.metadata IS 'Flexible JSONB field for non-critical, backend-interpreted account attributes.';
COMMENT ON COLUMN accounts.enabled IS 'Indicates whether the account is active and can participate in operations.';

CREATE INDEX idx_accounts_user_id ON accounts(user_id);
CREATE INDEX idx_accounts_user_currency ON accounts(user_id, currency_id);
CREATE INDEX idx_accounts_user_type ON accounts(user_id, type_id);
CREATE INDEX idx_accounts_user_enabled ON accounts(user_id, enabled);
CREATE INDEX idx_accounts_metadata_gin ON accounts USING GIN (metadata);

CREATE TRIGGER update_accounts_timestamp
BEFORE UPDATE ON accounts
FOR EACH ROW
EXECUTE FUNCTION update_timestamp();