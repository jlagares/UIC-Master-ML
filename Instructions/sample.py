import requests
import json

url = "https://dbc-37e75433-85a6.cloud.databricks.com/serving-endpoints/databricks-meta-llama-3-1-8b-instruct/invocations"

headers = {
    "Authorization": f"Bearer {DATABRICKS_TOKEN}",
    "Content-Type": "application/json"
}

payload = {
    "messages": [
        {
            "role": "user",
            "content": "Explain CAP theorem in simple terms"
        }
    ],
    "max_tokens": 300,
    "temperature": 0.7
}

response = requests.post(url, headers=headers, json=payload)
response.raise_for_status()

result = response.json()
result
