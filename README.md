# UIC Master ML — Databricks Training Curriculum

Hands-on training material for data engineering and GenAI workflows on Databricks. The curriculum covers Unity Catalog exploration, Delta Lake pipelines, SQL stored functions, and LLM-powered sentiment classification using Meta Llama models.

> **All notebooks run inside Databricks clusters.** No local Python environment is required.

---

## Prerequisites

- Access to a Databricks workspace with Unity Catalog enabled
- The `team_3d_dev.poc` catalog and schema created and accessible
- `DATABRICKS_TOKEN` environment variable set (only needed for `sample.py`)

---

## Repository Structure

```
sample.py                         # Standalone Python script — calls Databricks LLM endpoint via REST API
Instructions/
  Step By Step usage.ipynb        # Platform onboarding: Databricks UI, GitHub, Jobs, SQL, Genie
Notebooks/
  From Table to GenAI.ipynb       # Main demo: data join → Delta table → SQL function → LLM inference
```

---

## Instructions / Step By Step usage.ipynb

A guided walkthrough of the Databricks platform, intended as a live demo script for trainers or a self-paced tour for new users.

| Section | Content |
|---------|---------|
| **Workspace navigation** | Left-pane overview: Workspace, Catalog, Jobs, Compute, Marketplace, SQL, Data Engineering, AI/ML |
| **GitHub integration** | Connect the workspace to a GitHub repo; create a notebook and commit changes |
| **Catalog exploration** | Browse System, User, and Demo catalogs; query `samples.bakehouse.media_customer_reviews` from a notebook |
| **Jobs & Pipelines** | Create a job, build a pipeline, explain Fan-IN / Fan-OUT patterns, run and inspect logs |
| **SQL Editor** | Query editor walkthrough, execution plan visualization, BI dashboard creation |
| **Genie** | Free-text LLM-to-SQL feature demo |
| **Alerts & monitoring** | Table alerts, query history, SQL Warehouse management |
| **AI/ML transition** | Introduction to ML Runs; handoff to `From Table to GenAI.ipynb` |

---

## Notebooks / From Table to GenAI.ipynb

An end-to-end data + AI pipeline demonstrating how to go from raw catalog data to LLM-driven insights in six steps.

### Cell 1 — Configuration
Sets the target catalog:
```python
TARGET_CATALOG = "team_3d_dev.poc"
```

### Cell 2 — Data join
Reads `samples.bakehouse.sales_franchises` and `samples.bakehouse.media_customer_reviews` from Unity Catalog, inner-joins them on `franchiseID` (keeping only franchises that have reviews), and limits to 100 rows.

### Cell 3 — Persist to Delta Lake
Writes the joined DataFrame to a Delta table:
```
team_3d_dev.poc.franchises_with_reviews
```
Uses `.format("delta").mode("overwrite")`.

### Cell 4 — SQL stored function
Creates (or replaces) a reusable SQL function in the target catalog. The function accepts `num_franchises` and `num_results` parameters, aggregates reviews per franchise with `COLLECT_LIST()` and `COUNT()`, and returns the top franchises by review volume.

### Cell 5 — Playground prompt (Markdown)
Instructions for exploring the data interactively in the Databricks AI Playground using Meta Llama 3.3 70B Instruct. Includes a sample prompt to summarize franchise comments and generate a 1–5 star rating table.

### Cell 6 — LLM sentiment classification
Runs a `%sql` cell that calls `ai_query()` to classify each customer review as **positive**, **neutral**, or **negative** using Meta Llama 3.1 8B Instruct. Output is normalized to lowercase with `LOWER()`. Limited to 10 rows for demo purposes.

```sql
LOWER(ai_query(
    'databricks-meta-llama-3-1-8b-instruct',
    CONCAT('Classify the sentiment ... Return only one word.\n\nReview:\n', review)
)) AS review_category
```

---

## sample.py

Standalone Python script showing how to call a Databricks model serving endpoint directly via the REST API — useful for integrations outside of notebooks.

- Authenticates with a Bearer token from `DATABRICKS_TOKEN`
- Sends a chat-style payload to the Llama 3.1 8B endpoint
- Returns up to 300 tokens at temperature 0.7

```bash
export DATABRICKS_TOKEN=<your-token>
python sample.py
```

---

## Key Conventions

- **Fully qualified table names**: always `catalog.schema.table`
- **Delta Lake writes**: `.format("delta").mode("overwrite")`
- **In-database LLM inference**: `ai_query()` with explicit model name
- **Output normalization**: `LOWER()` on classification results
- **No hardcoded tokens**: use `DATABRICKS_TOKEN` environment variable

