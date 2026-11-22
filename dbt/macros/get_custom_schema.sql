{#
    Databricks/Unity Catalog teaching override.

    By default dbt concatenates the profile's target schema with any
    `+schema` config (e.g. "default_bronze"). For this class we want models
    to land directly in clean, purpose-named schemas -- bronze / silver / gold --
    inside the configured catalog, so the custom schema name is used as-is.
#}
{% macro generate_schema_name(custom_schema_name, node) -%}
    {%- if custom_schema_name is none -%}
        {{ target.schema }}
    {%- else -%}
        {{ custom_schema_name | trim }}
    {%- endif -%}
{%- endmacro %}
