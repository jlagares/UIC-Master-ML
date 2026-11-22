{#
    Reusable unit-conversion macro (Software Engineering / modularity pillar).
    Used in staging to derive a metric-unit column from the imperial
    samples.accuweather tables without duplicating the conversion formula.
#}
{% macro fahrenheit_to_celsius(column_name) -%}
    (({{ column_name }} - 32) * 5 / 9)
{%- endmacro %}
