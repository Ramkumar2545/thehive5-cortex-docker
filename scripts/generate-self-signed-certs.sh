#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

CERT_DIR="$ROOT_DIR/nginx/certs"
mkdir -p "$CERT_DIR"

echo "[*] Generating self-signed TLS certificate..."

openssl req -x509 -nodes -newkey rsa:4096 \
  -keyout "$CERT_DIR/thehive.key" \
  -out "$CERT_DIR/thehive.crt" \
  -days 825 \
  -subj "/C=IN/ST=Tamil Nadu/L=Chennai/O=Lab/OU=SOC/CN=localhost"

cp "$CERT_DIR/thehive.crt" "$CERT_DIR/thehive-ca.crt"

echo "[+] Generated: nginx/certs/thehive.key"
echo "[+] Generated: nginx/certs/thehive.crt"
echo "[+] Generated: nginx/certs/thehive-ca.crt"
echo

# Restart nginx if it is running
if docker compose ps nginx 2>/dev/null | grep -q "Up\|running"; then
  echo "[*] Restarting nginx to load new certificates..."
  docker compose restart nginx
  echo "[+] nginx restarted."
else
  echo "[!] nginx is not running — start the stack first with: docker compose up -d"
fi

echo
echo "[!] If you use a real domain, replace these files with proper CA-signed certs."
echo "    Files to replace:"
echo "      nginx/certs/thehive.key"
echo "      nginx/certs/thehive.crt"
echo "      nginx/certs/thehive-ca.crt"
