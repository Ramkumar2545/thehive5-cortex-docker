#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

CERT_DIR="$ROOT_DIR/nginx/certs"
mkdir -p "$CERT_DIR"

openssl req -x509 -nodes -newkey rsa:4096 \
  -keyout "$CERT_DIR/thehive.key" \
  -out "$CERT_DIR/thehive.crt" \
  -days 825 \
  -subj "/C=IN/ST=Tamil Nadu/L=Chennai/O=Lab/OU=SOC/CN=localhost"

cp "$CERT_DIR/thehive.crt" "$CERT_DIR/thehive-ca.crt"

echo "[+] Generated: nginx/certs/thehive.key"
echo "[+] Generated: nginx/certs/thehive.crt"
echo "[+] Generated: nginx/certs/thehive-ca.crt"
echo "[!] If you use a real domain, replace these files with proper CA-signed certs."
