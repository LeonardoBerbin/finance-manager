-- SCHEMA: Users, Sessions and Settings (database/schema/users.sql)
---------------------------------------------------------------------------------------------------------

-- RESET SCHEMA

DROP TABLE IF EXISTS user_settings CASCADE;
DROP TABLE IF EXISTS user_sessions CASCADE;
DROP TABLE IF EXISTS users CASCADE;

-- CREATE SCHEMA

CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255) NOT NULL UNIQUE,
    phone VARCHAR(20),
    password_hash VARCHAR(255) NOT NULL,
    enabled BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT name_format CHECK (char_length(name) >= 2),
    CONSTRAINT email_format CHECK (email ~ '^[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,}$'),
    CONSTRAINT phone_format CHECK (phone IS NULL OR phone ~ '^\+?[1-9]\d{1,14}$')
);

ALTER TABLE users ENABLE ROW LEVEL SECURITY;

COMMENT ON TABLE users IS 'Application users (authentication and identity)';
COMMENT ON COLUMN users.email IS 'Unique email address used for authentication (lowercase enforced)';

CREATE TRIGGER update_user_timestamp
BEFORE UPDATE ON users
FOR EACH ROW
EXECUTE FUNCTION update_timestamp();


CREATE TABLE user_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
    token VARCHAR(255) NOT NULL UNIQUE,
    expires_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_expires_at CHECK (expires_at > created_at)
);

ALTER TABLE user_sessions ENABLE ROW LEVEL SECURITY;

COMMENT ON TABLE user_sessions IS 'Active user sessions (authentication tokens)';
COMMENT ON COLUMN user_sessions.token IS 'Unique session token (should be stored hashed)';

CREATE INDEX idx_user_sessions_user_id 
ON user_sessions (user_id);

CREATE TYPE languages AS ENUM ('en', 'es');
CREATE TYPE themes AS ENUM ('light', 'dark');

COMMENT ON TYPE languages IS 'Supported application languages';
COMMENT ON TYPE themes IS 'Available UI themes';

CREATE TABLE user_settings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE UNIQUE NOT NULL,
    default_currency_id UUID REFERENCES currencies(id) ON DELETE SET NULL,
    language languages NOT NULL DEFAULT 'en',
    theme themes NOT NULL DEFAULT 'light',
    timezone VARCHAR(50) NOT NULL DEFAULT 'UTC',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE user_settings ENABLE ROW LEVEL SECURITY;

COMMENT ON TABLE user_settings IS 'User preferences and configuration (1:1 with users)';
COMMENT ON COLUMN user_settings.timezone IS 'IANA timezone identifier (e.g., America/Bogota)';

CREATE TRIGGER update_user_settings_timestamp
BEFORE UPDATE ON user_settings
FOR EACH ROW
EXECUTE FUNCTION update_timestamp();