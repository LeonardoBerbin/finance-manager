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
    metadata_schema JSONB NOT NULL,
    enabled BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_account_types_code_not_blank CHECK (length(trim(code)) > 0),
    CONSTRAINT chk_account_types_label_not_blank CHECK (length(trim(label)) > 0),
    CONSTRAINT chk_metadata_schema_valid
    CHECK (
        jsonb_matches_schema(
            get_jsonschema_object_definition(),
            metadata_schema
        )
    )
);

ALTER TABLE account_types ENABLE ROW LEVEL SECURITY;

COMMENT ON TABLE account_types IS 'Catalog of account types that define behavior, constraints, and metadata schema for accounts.';
COMMENT ON COLUMN account_types.code IS 'Internal unique identifier used by backend logic (e.g., savings, credit, loan).';
COMMENT ON COLUMN account_types.label IS 'Human-readable name used in UI.';
COMMENT ON COLUMN account_types.description IS 'Optional description explaining the purpose of the account type.';
COMMENT ON COLUMN account_types.is_liquid IS 'Indicates whether funds in this account type are immediately usable for transactions.';
COMMENT ON COLUMN account_types.metadata_schema IS 'JSON Schema used to validate account metadata dynamically.';
COMMENT ON COLUMN account_types.enabled IS 'Indicates whether this account type is available for use.';

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
    block_balance NUMERIC(36, 2) NOT NULL DEFAULT 0.00,
    metadata JSONB NOT NULL DEFAULT '{}',

    allow_negative_balance BOOLEAN GENERATED ALWAYS AS (COALESCE((metadata->>'allow_negative_balance')::boolean, false)) STORED,
    collateral_account_id UUID GENERATED ALWAYS AS ((metadata->>'collateral_account_id')::uuid) STORED,

    enabled BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_accounts_name_not_blank CHECK (length(trim(name)) > 0),
    CONSTRAINT chk_accounts_balance_non_negative CHECK (allow_negative_balance OR balance >= 0),
    CONSTRAINT chk_accounts_block_balance_non_negative CHECK (block_balance >= 0),
    CONSTRAINT uq_accounts_user_name UNIQUE (user_id, name),
    CONSTRAINT fk_collateral_account FOREIGN KEY (collateral_account_id) REFERENCES accounts(id)
);

ALTER TABLE accounts ENABLE ROW LEVEL SECURITY;

COMMENT ON TABLE accounts IS 'Represents financial accounts belonging to users, including balances, configuration metadata, and relationships to other accounts.';
COMMENT ON COLUMN accounts.user_id IS 'Owner of the account.';
COMMENT ON COLUMN accounts.currency_id IS 'Currency in which the account is denominated.';
COMMENT ON COLUMN accounts.type_id IS 'Reference to account_types defining behavior and metadata schema.';
COMMENT ON COLUMN accounts.name IS 'User-defined name for the account.';
COMMENT ON COLUMN accounts.description IS 'Optional description for additional context.';
COMMENT ON COLUMN accounts.balance IS 'Current available balance of the account.';
COMMENT ON COLUMN accounts.block_balance IS 'Amount reserved or blocked from usage.';
COMMENT ON COLUMN accounts.metadata IS 'Flexible JSONB field storing non-critical configuration and UI-related data.';
COMMENT ON COLUMN accounts.allow_negative_balance IS 'Derived flag indicating whether the account can go below zero.';
COMMENT ON COLUMN accounts.collateral_account_id IS 'Optional reference to another account used as collateral.';
COMMENT ON COLUMN accounts.enabled IS 'Indicates whether the account is active and usable.';

CREATE INDEX idx_accounts_user_id ON accounts(user_id);
CREATE INDEX idx_accounts_user_currency ON accounts(user_id, currency_id);
CREATE INDEX idx_accounts_user_type ON accounts (user_id, type_id);
CREATE INDEX idx_accounts_user_enabled ON accounts(user_id, enabled);
CREATE INDEX idx_accounts_collateral ON accounts(collateral_account_id);

CREATE INDEX idx_accounts_collateral_not_null ON accounts(collateral_account_id)
WHERE collateral_account_id IS NOT NULL;

CREATE INDEX idx_accounts_metadata_gin ON accounts 
USING GIN (metadata);

CREATE TRIGGER update_accounts_timestamp
BEFORE UPDATE ON accounts
FOR EACH ROW
EXECUTE FUNCTION update_timestamp();

---------------------------------------------------------------------------------------------------------
-- VALIDATION METADATA FUNCTION
---------------------------------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION validate_account_metadata()
RETURNS trigger AS $$
DECLARE
    schema JSONB;
BEGIN
    SELECT metadata_schema
    INTO schema
    FROM account_types
    WHERE id = NEW.type_id;

    IF schema IS NOT NULL THEN
        IF NOT jsonb_matches_schema(schema, NEW.metadata) THEN
            RAISE EXCEPTION 'Invalid metadata for account type %', NEW.type_id;
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION validate_account_metadata() IS
'Trigger function that validates accounts.metadata against the JSON Schema defined in account_types.metadata_schema. 
Ensures that account metadata complies with the structure and constraints defined per account type before insert or update.';

CREATE TRIGGER trigger_validate_account_metadata
BEFORE INSERT OR UPDATE ON accounts
FOR EACH ROW
EXECUTE FUNCTION validate_account_metadata();