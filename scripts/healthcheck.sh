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
