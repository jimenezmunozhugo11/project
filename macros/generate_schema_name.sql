-- ============================================================================
-- generate_schema_name — Returns the target schema name for a given node
-- ============================================================================
-- Usage:
--   {{ generate_schema_name('my_custom_schema', node) }}
--
-- Returns:
--   custom_schema_name — if a custom name is provided (not none)
--   target.schema      — fallback to the default target schema
-- ============================================================================

{% macro generate_schema_name(
    custom_schema_name, node
) -%}
    {%- set default_schema = target.schema -%}
    {%- if custom_schema_name
        is not none -%}
        {{ custom_schema_name | trim }}
    {%- else -%}
        {{ default_schema }}
    {%- endif -%}
{%- endmacro %}