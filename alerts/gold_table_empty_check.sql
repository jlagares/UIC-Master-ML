-- Alert condition query: used by the Databricks SQL Alert "Gold Table Empty:
-- fct_weather_sales_ai_summary" (see create_alert.ps1 / README.md in this
-- folder). The alert fires when row_count == 0, i.e. when the join between
-- weather and reviews produced no matching rows for the GenAI narrative step
-- -- the exact symptom hit earlier in this project (empty dashboard caused
-- by a city-join mismatch).
SELECT COUNT(*) AS row_count
FROM workspace.gold.fct_weather_sales_ai_summary
