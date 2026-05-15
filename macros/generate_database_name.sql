-- ============================================================================
-- generate_database_name — Returns the target database name for a given node
-- ============================================================================
-- Usage:
--   {{ generate_database_name('my_custom_db', node) }}
--
-- Returns:
--   custom_database_name — if a custom name is provided (not none)
--   target.database      — fallback to the default target database
-- ============================================================================

{% macro generate_database_name(
    custom_database_name, node
) -%}

    {%- if custom_database_name
            is not none -%}
        {{ custom_database_name | trim }}
    {%- else -%}
        {{ target.database | trim }}
    {%- endif -%}

{%- endmacro %}