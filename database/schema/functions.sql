---------------------------------------------------------------------------------------------------------------
-- GENERIC FUNCTIONS
---------------------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------------------
-- UPDATE TIMESTAMP FUNCTION
---------------------------------------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION update_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION update_timestamp() IS
'Generic trigger function that automatically updates the "updated_at" column to the current timestamp on row updates.
Requires the target table to include an "updated_at" column.';