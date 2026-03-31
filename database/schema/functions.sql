-- SCHEMA: Global Functions (database/scheme/functions.sql)
---------------------------------------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION update_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION update_timestamp() IS
'Trigger function that automatically updates the "updated_at" column to the current timestamp on row updates';