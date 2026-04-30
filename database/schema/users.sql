---------------------------------------------------------------------------------------------------------
-- RESET SCHEMA
---------------------------------------------------------------------------------------------------------

DROP TABLE IF EXISTS user_settings CASCADE;
DROP TABLE IF EXISTS user_sessions CASCADE;
DROP TABLE IF EXISTS users CASCADE;

---------------------------------------------------------------------------------------------------------
-- USERS DEFINITION
---------------------------------------------------------------------------------------------------------

CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255) NOT NULL UNIQUE,
    phone VARCHAR(20),
    password_hash VARCHAR(255) NOT NULL,
    enabled BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_users_name_not_blank CHECK (length(trim(name)) > 0),
    CONSTRAINT chk_users_email_format CHECK (email ~ '^[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,}$'),
    CONSTRAINT chk_users_phone_format CHECK (phone IS NULL OR phone ~ '^\+[1-9]\d{7,14}$')
);

ALTER TABLE users ENABLE ROW LEVEL SECURITY;

COMMENT ON TABLE users IS 'Application users representing identity and authentication data.';
COMMENT ON COLUMN users.email IS 'Unique email address used for authentication. Stored and compared in lowercase.';
COMMENT ON COLUMN users.name IS 'User display name used in UI (not a system identifier).';
COMMENT ON COLUMN users.phone IS 'Optional phone number in E.164 format (e.g., +573001234567).';
COMMENT ON COLUMN users.password_hash IS 'Hashed password using strong adaptive hashing algorithm (e.g., bcrypt or argon2).';

CREATE TRIGGER update_user_timestamp
BEFORE UPDATE ON users
FOR EACH ROW
EXECUTE FUNCTION update_timestamp();

---------------------------------------------------------------------------------------------------------------
-- USER SESSIONS DEFINITION
---------------------------------------------------------------------------------------------------------------

CREATE TABLE user_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
    token VARCHAR(255) NOT NULL UNIQUE,
    expires_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_used_at TIMESTAMPTZ,
    is_revoked BOOLEAN NOT NULL DEFAULT FALSE,

    CONSTRAINT chk_session_expires_after_create CHECK (expires_at > created_at)
);

ALTER TABLE user_sessions ENABLE ROW LEVEL SECURITY;

COMMENT ON TABLE user_sessions IS 'Authentication sessions issued by the backend representing active login sessions. Used for session validation, expiration, and revocation control.';
COMMENT ON COLUMN user_sessions.token IS 'Opaque session token used for authentication. Stored in plain form to allow direct lookup (must be generated with high entropy and transmitted securely via HTTPS).';
COMMENT ON COLUMN user_sessions.expires_at IS 'Expiration timestamp defining when the session becomes invalid.';
COMMENT ON COLUMN user_sessions.last_used_at IS 'Timestamp of last session activity, used for tracking and optional inactivity policies.';
COMMENT ON COLUMN user_sessions.is_revoked IS 'Indicates whether the session has been manually invalidated before expiration.';


CREATE INDEX idx_user_sessions_user_id ON user_sessions (user_id);
CREATE INDEX idx_user_sessions_token ON user_sessions (token);

---------------------------------------------------------------------------------------------------------
-- SETTINGS DEFINITION
---------------------------------------------------------------------------------------------------------

CREATE TABLE user_settings (
    user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    default_currency_id UUID REFERENCES currencies(id) ON DELETE RESTRICT,
    language VARCHAR(5) NOT NULL DEFAULT 'en',
    timezone VARCHAR(50) NOT NULL DEFAULT 'UTC',
    theme VARCHAR(50) NOT NULL DEFAULT 'light',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_settings_language_not_blank CHECK (length(trim(language)) > 0),
    CONSTRAINT chk_settings_theme_not_blank CHECK (length(trim(theme)) > 0),
    CONSTRAINT chk_settings_timezone_not_blank CHECK (length(trim(timezone)) > 0)
);

ALTER TABLE user_settings ENABLE ROW LEVEL SECURITY;

COMMENT ON TABLE user_settings IS 'User preferences and configuration in a 1:1 relationship with users.';
COMMENT ON COLUMN user_settings.language IS 'UI language preference (e.g. en). Must match supported language registry in application layer.';
COMMENT ON COLUMN user_settings.theme IS 'UI theme identifier used for frontend rendering (e.g., light, dark).';
COMMENT ON COLUMN user_settings.timezone IS 'IANA timezone identifier used for time normalization (e.g., America/Bogota).';
COMMENT ON COLUMN user_settings.default_currency_id IS 'Base currency used for financial calculations, reporting, and UI display (net worth, balances, conversions).';

CREATE TRIGGER update_user_settings_timestamp
BEFORE UPDATE ON user_settings
FOR EACH ROW
EXECUTE FUNCTION update_timestamp();