#!/usr/bin/env bash
# Quick manual cert generation + nginx restart
# Use this if generate-self-signed-certs.sh is not available
# or if you want to regenerate certs with a custom CN
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

CN="${1:-localhost}"

echo "[*] Generating cert for CN=${CN}"

mkdir -p nginx/certs

openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout nginx/certs/thehive.key \
  -out nginx/certs/thehive.crt \
  -subj "/CN=${CN}/O=TheHive/C=IN"

cp nginx/certs/thehive.crt nginx/certs/thehive-ca.crt

echo "[+] Generated: nginx/certs/thehive.key"
echo "[+] Generated: nginx/certs/thehive.crt"
echo "[+] Generated: nginx/certs/thehive-ca.crt"
echo
echo "[*] Restarting nginx..."
docker compose restart nginx
echo "[+] Done. nginx restarted with new certs."
