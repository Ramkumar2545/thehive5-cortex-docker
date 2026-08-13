#!/usr/bin/env bash
set -euo pipefail

# Installs a cron job that runs `docker container prune -f` every 15 minutes.
#
# WHY: Cortex spawns a new Docker container per analyzer job and does not
# always reap it immediately, especially under memory pressure. Left alone,
# stopped analyzer containers (and their overlay mounts) accumulate under
# concurrent job load and have been observed to cause container/mount
# teardown errors. This is a companion to
# scripts/prune-stale-analyzer-containers.sh (systemd timer variant, runs
# every 30 minutes) — use whichever fits your host's init system; running
# both is harmless but redundant.

CRON_MARKER="# thehive5-cortex-docker: prune stale analyzer containers"
CRON_LINE="*/15 * * * * docker container prune -f >> /var/log/docker-container-prune.log 2>&1 $CRON_MARKER"

if crontab -l 2>/dev/null | grep -qF "$CRON_MARKER"; then
  echo "[*] Cron entry already installed, nothing to do."
  exit 0
fi

(crontab -l 2>/dev/null; echo "$CRON_LINE") | crontab -
echo "[+] Installed cron job: docker container prune -f (every 15 minutes)"
echo "[+] Logs: /var/log/docker-container-prune.log"
echo "[*] Verify with: crontab -l"
