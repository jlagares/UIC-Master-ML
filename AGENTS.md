# Agent Guidelines — UIC Master ML

## Project Overview

Databricks training curriculum demonstrating data engineering and GenAI workflows. **Notebooks run inside Databricks clusters**, not locally. The pipeline flows: Unity Catalog data → Delta Lake → SQL functions → LLM inference.

## Architecture

| Layer | Technology | Notes |
|-------|-----------|-------|
| Platform | Databricks with Unity Catalog | All tables fully qualified: `catalog.schema.table` |
| Storage | Delta Lake | `.format("delta").mode("overwrite")` |
| Compute | Databricks clusters | No local runtime needed |
| LLM inference | `ai_query()` SQL function | In-database inference via Databricks model serving |
| LLM REST access | `requests` + Bearer token | Used in `sample.py` for API calls outside notebooks |
| Sample data | `samples.bakehouse` | Pre-loaded in every Databricks workspace |
| Target catalog | `team_3d_dev.poc` | Must exist and be accessible before running notebooks |

## Repository Structure

```
AGENTS.md                         # This file
README.md                         # Project overview
sample.py                         # Standalone REST API example for LLM endpoint calls
Instructions/
  Step By Step usage.ipynb        # Databricks platform onboarding walkthrough
Notebooks/
  From Table to GenAI.ipynb       # Main demo: data join → Delta table → SQL fn → LLM
.github/
  copilot-instructions.md         # VS Code Copilot workspace instructions
```

## Build & Run

- **No local setup required** — all notebooks run on Databricks clusters
- **`sample.py`** requires `DATABRICKS_TOKEN` set as an environment variable before running locally
- **No `requirements.txt`** — dependencies are provided by Databricks Runtime
- Run notebooks cell-by-cell in order; each cell builds on the previous output
- Ensure `team_3d_dev.poc` catalog and schema exist before executing `From Table to GenAI.ipynb`

## Conventions

### SQL
- Use CTEs (`WITH … AS`) for readability
- Aggregate reviews with `COLLECT_LIST()` and `COUNT()`
- Always use fully qualified table names: `catalog.schema.table`

### AI / LLM inference
- Prefer `ai_query()` for in-database batch inference
- Wrap output with `LOWER()` for consistent classification labels
- Pass the full model name explicitly: `'databricks-meta-llama-3-1-8b-instruct'`

### Authentication
- Store tokens in the `DATABRICKS_TOKEN` environment variable
- **Never hardcode tokens** in notebooks or source files

### Notebooks
- Lead each logical section with a Markdown cell explaining the step
- Keep code cells focused on a single operation (read, join, write, query, infer)

## Key Patterns

**Delta Lake write:**
```python
df.write.format("delta").mode("overwrite").saveAsTable("catalog.schema.table")
```

**SQL sentiment classification with `ai_query()`:**
```sql
LOWER(ai_query(
    'databricks-meta-llama-3-1-8b-instruct',
    CONCAT('Classify sentiment as positive, neutral, or negative. Return one word.\n\nReview:\n', review)
)) AS review_category
```

**REST API call to model serving endpoint (`sample.py` pattern):**
```python
import os, requests
headers = {"Authorization": f"Bearer {os.environ['DATABRICKS_TOKEN']}"}
payload = {"messages": [{"role": "user", "content": prompt}], "max_tokens": 300}
response = requests.post(ENDPOINT_URL, headers=headers, json=payload)
```

## Model

Meta Llama 3.1 8B Instruct — served via Databricks model serving.  
For playground exploration, Meta Llama 3.3 70B Instruct is also available.
