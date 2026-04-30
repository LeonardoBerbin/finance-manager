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
    is_liquid BOOLEAN NOT NULL DEFAULT FALSE,
    allowed_negative_balance BOOLEAN NOT NULL DEFAULT FALSE,
    metadata_definition JSONB NOT NULL DEFAULT '{}',
    enabled BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_account_types_code_not_blank CHECK (length(trim(code)) > 0),
    CONSTRAINT chk_account_types_label_not_blank CHECK (length(trim(label)) > 0),
    CONSTRAINT chk_account_types_metadata_is_object CHECK (jsonb_typeof(metadata_definition) = 'object')
);

ALTER TABLE account_types ENABLE ROW LEVEL SECURITY;

COMMENT ON TABLE account_types IS 'Defines account categories and their metadata contract used by backend validation logic.';
COMMENT ON COLUMN account_types.code IS 'Internal identifier used by backend logic (e.g. savings, credit, loan).';
COMMENT ON COLUMN account_types.label IS 'Human-readable label used in UI.';
COMMENT ON COLUMN account_types.description IS 'Optional description of the account type.';
COMMENT ON COLUMN account_types.is_liquid IS 'Indicates whether this account type represents liquid funds usable for transactions.';
COMMENT ON COLUMN account_types.allowed_negative_balance IS 'Default rule indicating whether accounts of this type may go negative.';
COMMENT ON COLUMN account_types.metadata_definition IS 'Backend-driven JSON contract defining allowed metadata structure for accounts of this type.';
COMMENT ON COLUMN account_types.enabled IS 'Indicates whether this account type is available for creation.';

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
    balance NUMERIC(36, 2) NOT NULL DEFAULT 0.00,
    blocked_balance NUMERIC(36, 2) NOT NULL DEFAULT 0.00,
    metadata JSONB NOT NULL DEFAULT '{}',
    collateral_account_id UUID NULL,
    enabled BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_accounts_name_not_blank CHECK (length(trim(name)) > 0),
    CONSTRAINT chk_accounts_blocked_balance_valid CHECK (blocked_balance >= 0 AND blocked_balance <= balance),
    CONSTRAINT uq_accounts_user_name UNIQUE (user_id, name),
    CONSTRAINT chk_accounts_metadata_is_object CHECK (jsonb_typeof(metadata) = 'object'),
    CONSTRAINT chk_accounts_no_self_collateral CHECK (collateral_account_id IS NULL OR collateral_account_id <> id),
    CONSTRAINT fk_accounts_collateral
        FOREIGN KEY (collateral_account_id)
        REFERENCES accounts(id)
        ON DELETE SET NULL
);

ALTER TABLE accounts ENABLE ROW LEVEL SECURITY;

COMMENT ON TABLE accounts IS 'Represents user financial accounts including cash, credit, loans, investments and collateral relationships.';
COMMENT ON COLUMN accounts.user_id IS 'Owner of the account.';
COMMENT ON COLUMN accounts.currency_id IS 'Currency in which the account balance is denominated.';
COMMENT ON COLUMN accounts.type_id IS 'Reference to account_types defining behavior and metadata contract.';
COMMENT ON COLUMN accounts.name IS 'User-defined account name for display purposes.';
COMMENT ON COLUMN accounts.description IS 'Optional descriptive field for user context.';
COMMENT ON COLUMN accounts.balance IS 'Available balance of the account.';
COMMENT ON COLUMN accounts.block_balance IS 'Reserved or blocked funds not available for spending.';
COMMENT ON COLUMN accounts.metadata IS 'Flexible JSONB field validated by backend according to account_types.metadata_definition.';
COMMENT ON COLUMN accounts.collateral_account_id IS 'Optional backup account used as collateral to cover debt or insufficient funds situations.';
COMMENT ON COLUMN accounts.enabled IS 'Indicates whether the account is active and usable.';

CREATE INDEX idx_accounts_user_id ON accounts(user_id);
CREATE INDEX idx_accounts_user_currency ON accounts(user_id, currency_id);
CREATE INDEX idx_accounts_user_type ON accounts(user_id, type_id);
CREATE INDEX idx_accounts_user_enabled ON accounts(user_id, enabled);
CREATE INDEX idx_accounts_metadata_gin ON accounts USING GIN (metadata);
CREATE INDEX idx_accounts_collateral ON accounts(collateral_account_id);

CREATE TRIGGER update_accounts_timestamp
BEFORE UPDATE ON accounts
FOR EACH ROW
EXECUTE FUNCTION update_timestamp();

---------------------------------------------------------------------------------------------------------
-- ACCOUNT BALANCE VALIDATION FUNCTION
---------------------------------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION validate_account_balance()
RETURNS TRIGGER AS $$
DECLARE
    allow_negative BOOLEAN;
BEGIN
    SELECT allow_negative INTO allow_negative
    FROM account_types WHERE id = NEW.type_id;

    IF NOT COALESCE(allow_negative, FALSE) AND NEW.balance < 0 THEN
        RAISE EXCEPTION 'negative balance not allowed for account type %', NEW.type_id;
        USING ERRCODE = 'check_violation';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION validate_account_balance() IS
'Validates account balance rules based on account type configuration.
Prevents negative balances when the account type does not allow it.';

CREATE TRIGGER trigger_validate_account_balance
BEFORE INSERT OR UPDATE ON accounts
FOR EACH ROW
EXECUTE FUNCTION validate_account_balance();