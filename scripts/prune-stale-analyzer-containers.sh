#!/usr/bin/env bash
set -euo pipefail

# Removes exited/dead Cortex analyzer worker containers and their dangling
# containerd mounts. Cortex spawns a new container per analyzer job and does
# not always reap it immediately, especially under memory pressure — leaving
# stopped containers (and occasionally orphaned /tmp/containerd-mount* dirs)
# behind. Run this on a schedule (see systemd/docker-prune.timer) rather than
# only when you notice a problem.

echo "[*] Exited containers before prune:"
docker ps -a --filter status=exited --filter status=dead --format '{{.ID}}  {{.Image}}  {{.Status}}'

echo "[*] Pruning stopped containers older than 1h..."
docker container prune -f --filter "until=1h"

echo "[*] Pruning dangling images..."
docker image prune -f

echo "[*] Done. Remaining exited containers:"
docker ps -a --filter status=exited --filter status=dead --format '{{.ID}}  {{.Image}}  {{.Status}}' | wc -l
