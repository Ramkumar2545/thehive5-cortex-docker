#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

mkdir -p \
  cassandra/data cassandra/logs \
  elasticsearch/data elasticsearch/logs \
  thehive/config thehive/data/files thehive/logs \
  cortex/config cortex/logs cortex/neurons cortex/cortex-jobs \
  nginx/templates nginx/certs

if [[ ! -f .env ]]; then
  cp .env.example .env
  echo "[+] Created .env from .env.example"
fi

if [[ ! -f thehive/config/secret.conf ]]; then
  cp thehive/config/secret.conf.template thehive/config/secret.conf
  echo "[+] Created thehive/config/secret.conf"
fi

if [[ ! -f cortex/config/secret.conf ]]; then
  cp cortex/config/secret.conf.template cortex/config/secret.conf
  echo "[+] Created cortex/config/secret.conf"
fi

if [[ ! -f thehive/config/index.conf ]]; then
  cp thehive/config/index.conf.template thehive/config/index.conf
  echo "[+] Created thehive/config/index.conf"
fi

if [[ ! -f cortex/config/index.conf ]]; then
  cp cortex/config/index.conf.template cortex/config/index.conf
  echo "[+] Created cortex/config/index.conf"
fi

echo "[!] Update placeholder secrets before starting containers."
echo "[!] Also place TLS files in nginx/certs if you want HTTPS through nginx."
