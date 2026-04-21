#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

echo "[*] Creating required directories..."
mkdir -p \
  cassandra/data cassandra/logs \
  elasticsearch/data elasticsearch/logs \
  thehive/config thehive/data/files thehive/logs \
  cortex/config cortex/logs cortex/neurons cortex/cortex-jobs \
  nginx/templates nginx/certs

# ─── .env ────────────────────────────────────────────────────────────────────
if [[ ! -f .env ]]; then
  cp .env.example .env
  echo "[+] Copied .env.example → .env"
fi

# ─── TheHive configs ─────────────────────────────────────────────────────────
echo "[*] Copying thehive templates..."
cp thehive/config/index.conf.template  thehive/config/index.conf
echo "[+] Copied index.conf.template  → thehive/config/index.conf"

cp thehive/config/secret.conf.template thehive/config/secret.conf
echo "[+] Copied secret.conf.template → thehive/config/secret.conf"

# ─── Cortex configs ──────────────────────────────────────────────────────────
echo "[*] Copying cortex templates..."
cp cortex/config/index.conf.template   cortex/config/index.conf
echo "[+] Copied index.conf.template  → cortex/config/index.conf"

cp cortex/config/secret.conf.template  cortex/config/secret.conf
echo "[+] Copied secret.conf.template → cortex/config/secret.conf"

# ─── Print next-steps checklist ──────────────────────────────────────────────
echo
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║            FILES COPIED — NOW EDIT THESE FILES              ║"
echo "╠══════════════════════════════════════════════════════════════╣"
echo "║                                                              ║"
echo "║  1. .env                                                     ║"
echo "║     → Set UID, GID, ELASTICSEARCH_PASSWORD, secrets          ║"
echo "║                                                              ║"
echo "║  2. thehive/config/index.conf                                ║"
echo "║     → Replace ###CHANGEME_ELASTICSEARCH_PASSWORD###          ║"
echo "║       with the SAME password as in .env                      ║"
echo "║                                                              ║"
echo "║  3. cortex/config/index.conf                                 ║"
echo "║     → Replace ###CHANGEME_ELASTICSEARCH_PASSWORD###          ║"
echo "║       with the SAME password as in .env                      ║"
echo "║                                                              ║"
echo "║  4. thehive/config/secret.conf                               ║"
echo "║     → Replace ###CHANGEME_THEHIVE_SECRET###                  ║"
echo "║       with output of: openssl rand -base64 48                ║"
echo "║                                                              ║"
echo "║  5. cortex/config/secret.conf                                ║"
echo "║     → Replace ###CHANGEME_CORTEX_SECRET###                   ║"
echo "║       with output of: openssl rand -base64 48                ║"
echo "║                                                              ║"
echo "╠══════════════════════════════════════════════════════════════╣"
echo "║  CRITICAL: Elasticsearch password must be IDENTICAL in:      ║"
echo "║    .env / thehive/config/index.conf / cortex/config/index.conf║"
echo "╠══════════════════════════════════════════════════════════════╣"
echo "║  Optional: generate self-signed TLS certs:                   ║"
echo "║    ./scripts/generate-self-signed-certs.sh                   ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo
echo "When done editing, start with:"
echo "  docker compose pull && docker compose up -d"
