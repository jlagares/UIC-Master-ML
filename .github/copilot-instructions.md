# Project Guidelines

## Project Overview

Databricks training curriculum for data engineering + GenAI workflows. Notebooks run **inside Databricks**, not locally. The pipeline flows: Unity Catalog data → Delta Lake → SQL functions → LLM inference.

## Architecture

- **Platform**: Databricks with Unity Catalog enabled
- **Storage**: Delta Lake (`.format("delta").mode("overwrite")`)
- **Catalog convention**: All table references are fully qualified — `catalog.schema.table` (e.g., `team_3d_dev.poc.franchises_with_reviews`)
- **LLM inference**: Use `ai_query()` SQL function for in-database inference; use `requests` + Bearer token for REST API calls to Databricks model serving endpoints
- **Sample data**: Lives in `samples.bakehouse` (pre-loaded in Databricks workspaces)
- **Target catalog**: `team_3d_dev.poc` — must exist and be accessible before running notebooks

## Key Files

| File | Purpose |
|------|---------|
| `sample.py` | Standalone Python example for calling Databricks LLM serving endpoints via REST API |
| `Instructions/Step By Step usage.ipynb` | Platform onboarding walkthrough (Databricks UI, GitHub, Genie, Jobs) |
| `Notebooks/From Table to GenAI.ipynb` | Main demo: data join → Delta table → SQL function → LLM sentiment classification |

## Conventions

- **SQL style**: Use CTEs for readability; aggregate reviews with `COLLECT_LIST()` and `COUNT()`
- **AI inference**: Use `ai_query()` with explicit model name and lowercase output (`LOWER()`) for classification tasks
- **Auth**: `DATABRICKS_TOKEN` environment variable for REST API calls — never hardcode tokens
- **Notebooks**: Each cell builds on previous output; include Markdown cells for step-by-step guidance

## Environment

- No local Python environment needed — notebooks run on Databricks clusters
- `sample.py` requires `DATABRICKS_TOKEN` set in the local shell environment
- No `requirements.txt` — dependencies are provided by Databricks Runtime
- Model used: Meta Llama 3.1 8B Instruct (endpoint via Databricks model serving)
