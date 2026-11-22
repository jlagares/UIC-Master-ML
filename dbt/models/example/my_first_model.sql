-- Minimal smoke-test model: no source tables required, just proves the
-- connection, auth, and warehouse compute are working end-to-end.
select 1 as id, 'hello from dbt on databricks' as message
