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

# Auto-set CORTEX_DOCKER_JOB_DIRECTORY to the real absolute host path.
# This MUST be an absolute path — Docker passes it directly to spawned
# analyzer containers as a bind-mount source. A wrong or relative path
# causes workers to start with empty stdin → JSONDecodeError.
JOBS_DIR="${ROOT_DIR}/cortex/cortex-jobs"
sed -i "s|CORTEX_DOCKER_JOB_DIRECTORY=.*|CORTEX_DOCKER_JOB_DIRECTORY=${JOBS_DIR}|" .env
echo "[+] Auto-set CORTEX_DOCKER_JOB_DIRECTORY=${JOBS_DIR}"

# Auto-set UID and GID from the current user so volume mounts work correctly.
CURRENT_UID="$(id -u)"
CURRENT_GID="$(id -g)"
sed -i "s|^UID=.*|UID=${CURRENT_UID}|" .env
sed -i "s|^GID=.*|GID=${CURRENT_GID}|" .env
echo "[+] Auto-set UID=${CURRENT_UID} GID=${CURRENT_GID}"

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
echo "║  AUTO-CONFIGURED (no action needed):                         ║"
echo "║    ✔ CORTEX_DOCKER_JOB_DIRECTORY  (set to this machine path) ║"
echo "║    ✔ UID / GID                    (set from current user)    ║"
echo "║                                                              ║"
echo "║  STILL REQUIRED — edit .env:                                 ║"
echo "║    → ELASTICSEARCH_PASSWORD  (replace placeholder)           ║"
echo "║    → THEHIVE_SECRET          (openssl rand -base64 48)       ║"
echo "║    → CORTEX_SECRET           (openssl rand -base64 48)       ║"
echo "║                                                              ║"
echo "║  1. thehive/config/index.conf                                ║"
echo "║     → Replace ###CHANGEME_ELASTICSEARCH_PASSWORD###          ║"
echo "║       with the SAME password as in .env                      ║"
echo "║                                                              ║"
echo "║  2. cortex/config/index.conf                                 ║"
echo "║     → Replace ###CHANGEME_ELASTICSEARCH_PASSWORD###          ║"
echo "║       with the SAME password as in .env                      ║"
echo "║                                                              ║"
echo "║  3. thehive/config/secret.conf                               ║"
echo "║     → Replace ###CHANGEME_THEHIVE_SECRET###                  ║"
echo "║       with output of: openssl rand -base64 48                ║"
echo "║                                                              ║"
echo "║  4. cortex/config/secret.conf                                ║"
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
