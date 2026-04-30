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


---------------------------------------------------------------------------------------------------------------
-- JSON SCHEMA BASE VALIDATOR
---------------------------------------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION get_jsonschema_object_definition()
RETURNS JSONB AS $$
SELECT '{
    "type": "object",
    "properties": {
        "type": { "const": "object" },
        "properties": { "type": "object" },
        "required": { "type": "array" },
        "additionalProperties": { "type": "boolean" }
    },
    "required": ["type","properties","required","additionalProperties"],
    "additionalProperties": false
}'::jsonb;
$$ LANGUAGE sql IMMUTABLE;

COMMENT ON FUNCTION get_jsonschema_object_definition() IS
'Returns a base JSON Schema definition used to validate that a JSONB column contains a valid JSON Schema object structure.
Used to enforce that metadata_schema fields follow a consistent schema definition format.';