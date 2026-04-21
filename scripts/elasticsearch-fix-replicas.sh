#!/usr/bin/env bash
# =============================================================================
# Fix Elasticsearch yellow status on single-node deployment
# 
# On a single-node ES cluster, replica shards can never be assigned
# (you need 2+ nodes for replicas). This script sets replicas=0 on
# all existing indices and adds a template so future indices also
# start with replicas=0, keeping the cluster permanently GREEN.
#
# Usage:
#   ./scripts/elasticsearch-fix-replicas.sh
#
# Optional: pass custom ES password as first argument
#   ./scripts/elasticsearch-fix-replicas.sh MyPassword123
# =============================================================================
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

# Load password from .env if not passed as argument
if [ -n "${1:-}" ]; then
  ES_PASS="$1"
elif [ -f .env ]; then
  ES_PASS="$(grep '^ELASTICSEARCH_PASSWORD=' .env | cut -d'=' -f2)"
else
  echo "[!] Could not find ELASTICSEARCH_PASSWORD. Pass it as argument:"
  echo "    $0 YourPassword"
  exit 1
fi

ES_URL="http://localhost:9200"
ES_USER="elastic"

echo "[*] Checking Elasticsearch cluster health..."
curl -sf -u "${ES_USER}:${ES_PASS}" "${ES_URL}/_cluster/health?pretty" || {
  echo "[!] Could not reach Elasticsearch at ${ES_URL}"
  echo "    Make sure the stack is running: docker compose up -d"
  exit 1
}

echo
echo "[*] Setting number_of_replicas=0 on ALL existing indices..."
curl -sf -u "${ES_USER}:${ES_PASS}" \
  -X PUT "${ES_URL}/_settings" \
  -H "Content-Type: application/json" \
  -d '{"index":{"number_of_replicas":0}}'
echo

echo "[*] Creating index template so future indices also use replicas=0..."
curl -sf -u "${ES_USER}:${ES_PASS}" \
  -X PUT "${ES_URL}/_index_template/single-node" \
  -H "Content-Type: application/json" \
  -d '{
    "index_patterns": ["*"],
    "template": {
      "settings": {
        "number_of_replicas": 0
      }
    },
    "priority": 1
  }'
echo

echo "[*] Final cluster health check..."
curl -sf -u "${ES_USER}:${ES_PASS}" "${ES_URL}/_cluster/health?pretty"

echo
echo "[+] Done. Elasticsearch cluster should now be GREEN."
