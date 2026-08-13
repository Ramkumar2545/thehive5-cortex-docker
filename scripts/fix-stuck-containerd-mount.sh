#!/usr/bin/env bash
set -euo pipefail

# Recovery for:
#   Error response from daemon: failed to unmount /tmp/containerd-mount<ID>:
#   failed to unmount target /tmp/containerd-mount<ID>: device or resource busy
#
# This happens when a process (often an OOM-killed analyzer worker, or a
# short-lived container torn down while something still has an open fd/lock
# on its overlayfs mount) leaves a containerd-mount directory that the kernel
# refuses to unmount normally. Run this on the DOCKER HOST (not inside a
# container). Requires root.

if [[ $EUID -ne 0 ]]; then
  echo "Run as root (sudo)." >&2
  exit 1
fi

echo "[*] Stuck containerd mounts under /tmp:"
mapfile -t stuck < <(mount | awk '$3 ~ /^\/tmp\/containerd-mount/ {print $3}')

if [[ ${#stuck[@]} -eq 0 ]]; then
  echo "    none found via mount table"
else
  for m in "${stuck[@]}"; do
    echo "    lazy-unmounting: $m"
    umount -l "$m" || echo "    (already gone or failed: $m)"
  done
fi

echo "[*] Stopping docker before restarting containerd..."
systemctl stop docker.socket docker.service

echo "[*] Restarting containerd..."
systemctl restart containerd
sleep 2

echo "[*] Starting docker..."
systemctl start docker.service

echo "[*] Removing any leftover empty containerd-mount directories..."
find /tmp -maxdepth 1 -type d -name 'containerd-mount*' -empty -exec rmdir {} \; 2>/dev/null || true

echo "[*] Done. Verify with: docker ps -a  and  docker compose -f /opt/thehive5-cortex-docker/docker-compose.yml ps"
