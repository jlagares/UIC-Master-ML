# syntax=docker/dockerfile:1
FROM python:3.12-slim

# Install OS build deps needed by some dbt/adapter wheels
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        git \
        ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Install the latest stable dbt release with the Databricks adapter
# (dbt-databricks pulls in the required dbt-core dependency automatically)
RUN pip install --no-cache-dir --upgrade pip \
    && pip install --no-cache-dir dbt-databricks

WORKDIR /usr/app

ENTRYPOINT ["dbt"]
CMD ["--help"]
