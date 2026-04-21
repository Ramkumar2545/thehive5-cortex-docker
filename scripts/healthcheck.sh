#!/usr/bin/env bash
set -euo pipefail

echo "== Docker Compose status =="
docker compose ps

echo
echo "== TheHive status =="
curl -fsS http://localhost:9000/thehive/api/status || true

echo
echo "== Cortex status =="
curl -fsS http://localhost:9001/cortex/api/status || true

echo
echo "== Elasticsearch health =="
if [[ -f .env ]]; then
  ES_PASSWORD=$(grep '^ELASTICSEARCH_PASSWORD=' .env | cut -d'=' -f2-)
  curl -fsS -u "elastic:${ES_PASSWORD}" http://localhost:9200/_cat/health || true
else
  echo ".env file not found, skipping Elasticsearch authenticated health check"
fi
