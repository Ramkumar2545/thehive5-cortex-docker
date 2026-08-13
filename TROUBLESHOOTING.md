# Troubleshooting

## `json.decoder.JSONDecodeError: Expecting value: line 1 column 1 (char 0)`

### Symptom

Cortex analyzer (e.g. VirusTotal) crashes immediately with:

```
File "/usr/local/lib/python3.x/site-packages/cortexutils/worker.py", line 37, in __init__
    self._input = json.load(sys.stdin)
json.decoder.JSONDecodeError: Expecting value: line 1 column 1 (char 0)
```

This means the worker process started but received **empty stdin**. Cortex normally pipes the job JSON payload into the worker's stdin when it spawns the container. Empty stdin = job dispatch failure upstream.

---

### Root Cause 1 — Wrong `CORTEX_DOCKER_JOB_DIRECTORY` (most common)

Cortex spawns a new Docker container per analyzer job. It bind-mounts the job directory from the host into the worker container so the worker can read the job input file.

If `CORTEX_DOCKER_JOB_DIRECTORY` in your `.env` is:
- A **relative path** (e.g. `./cortex/cortex-jobs`) — Docker cannot resolve it
- A **path that doesn't exist** on the host
- A **path from a different machine** (e.g. the default example value)

...the worker container starts but stdin is empty → `JSONDecodeError`.

**Fix:**

```bash
# From the repo root, get the correct absolute path:
echo "$(pwd)/cortex/cortex-jobs"

# Set that value in .env:
CORTEX_DOCKER_JOB_DIRECTORY=/absolute/path/to/thehive5-cortex-docker/cortex/cortex-jobs
```

Also make sure the directory exists and has the right permissions:

```bash
mkdir -p cortex/cortex-jobs
chown -R 1000:1000 cortex/cortex-jobs
chmod -R 777 cortex/cortex-jobs
```

Then restart Cortex:

```bash
docker compose restart cortex
```

---

### Root Cause 2 — Python 3.14 incompatibility

`cortexutils` uses `json.load(sys.stdin)` which relies on the standard stdin stream. Python 3.14 changed internal buffering behavior that breaks this in Docker-spawned subprocesses.

**Fix:** Pin the Python image in `cortex/config/application.conf`:

```hocon
docker {
  pythonImage = "python:3.11-slim"
}
```

This is already set in the current `cortex/config/application.conf`. Do not change it to 3.12+ or `latest`.

---

### Root Cause 3 — Analyzer run manually (not via Cortex)

Analyzer scripts **must be invoked by Cortex**, which pipes the job JSON via stdin. Running the script directly from the terminal produces empty stdin.

If you need to test locally:

```bash
echo '{"dataType":"hash","data":"abc123","config":{"key":"YOUR_VT_API_KEY"},"parameters":{}}' \
  | python virustotal.py
```

---

### Diagnosis checklist

```bash
# 1. Check CORTEX_DOCKER_JOB_DIRECTORY is set and absolute
grep CORTEX_DOCKER_JOB_DIRECTORY .env

# 2. Check the directory exists on the host
ls -la cortex/cortex-jobs/

# 3. Confirm Docker can see the socket
ls -la /var/run/docker.sock

# 4. Check Cortex logs for job dispatch errors
docker compose logs cortex | grep -i "error\|job\|docker" | tail -50

# 5. Check what Python image gets pulled for workers
docker images | grep python
```

---

## Cortex container restarts in a loop

**Symptom:** `docker compose ps` shows Cortex restarting repeatedly.

**Common causes:**
- Secret or index config placeholder not replaced — check `cortex/config/secret.conf` and `cortex/config/index.conf` for `###CHANGEME###` strings
- Elasticsearch not yet healthy when Cortex starts — wait for `docker compose ps` to show elasticsearch as healthy before checking Cortex
- Wrong Elasticsearch password — password in `cortex/config/index.conf` must exactly match `ELASTICSEARCH_PASSWORD` in `.env`

```bash
# Check for unreplaced placeholders
grep -r 'CHANGEME' cortex/config/

# Tail Cortex startup logs
docker compose logs -f cortex
```

---

## VirusTotal analyzer returns no results

- Confirm your VT API key is set in the Cortex UI under **Organization > Analyzers > VirusTotal**
- Check outbound internet access from the Cortex container: `docker exec cortex curl -I https://www.virustotal.com`
- Verify the analyzer image pulls successfully: `docker pull python:3.11-slim`

---

## `failed to unmount /tmp/containerd-mount<ID>: device or resource busy`

### Symptom

```
Error response from daemon: failed to unmount /tmp/containerd-mount<ID>:
failed to unmount target /tmp/containerd-mount<ID>: device or resource busy
```

Shows up during/after Cortex analyzer jobs, with a different mount ID each
time. Cortex spawns one Docker container per analyzer job (4 containers per
alert if you run VirusTotal, AlienVault OTX, ThreatFox, and MalwareBazaar),
so this is a high-churn container-teardown path.

### Root cause

This is a known containerd/overlayfs teardown race, not a `docker-compose.yml`
or `CORTEX_DOCKER_JOB_DIRECTORY` misconfiguration — a wrong job directory
produces the `JSONDecodeError` documented above, not a mount-busy error. The
unmount fails when something still holds a reference to the container's
overlay mount at the moment dockerd tries to tear it down. In a
high-churn, memory-constrained setup like this one, by far the most common
trigger is the **kernel OOM-killer SIGKILLing an analyzer worker mid-run**
(cgroup memory limit exceeded) — the process is killed before it releases
its mount namespace reference, so containerd's cleanup step races the
kernel and loses.

**Confirm which trigger applies to you** before "fixing" the wrong thing —
run these on the Docker host at/after the next occurrence:

```bash
# OOM kills correlate with mount-busy errors?
journalctl -k --since "2 hours ago" | grep -i "oom\|killed process"
journalctl -u docker -u containerd --since "2 hours ago" | grep -i mount

# Was memory actually exhausted when the 4 analyzers ran concurrently?
free -h
docker stats --no-stream

# Stale container buildup (also known to leave dangling mounts)?
docker ps -a | grep -c Exited

# Disk pressure on the Docker data root or /tmp?
df -h /var/lib/docker /tmp
```

If `journalctl -k` shows OOM kills lining up with the mount errors, the
root cause is memory pressure, not a code/config bug — see the memory
guidance below. If instead you see large `Exited` container counts with no
OOM kills, it's stale-container buildup and `docker container prune` on a
schedule is the fix — either `scripts/setup-cleanup-cron.sh` (cron, every
15 min) or `systemd/docker-prune.{service,timer}` +
`scripts/prune-stale-analyzer-containers.sh` (systemd timer, every 30 min).
Pick one; running both is harmless but redundant.

**Audited and ruled out:** a `job.directory` / `job.dockerDirectory` path
mismatch between the `cortex` container and its spawned sibling analyzer
containers. Verified against the Cortex docker image's entrypoint script and
`DockerJobRunnerSrv.scala` — this repo's `job_directory=/tmp/cortex-jobs` /
`docker_job_directory=${CORTEX_DOCKER_JOB_DIRECTORY}` setup in
`docker-compose.yml` is the correct, working configuration (see the comment
block in `cortex/config/application.conf`). A real path mismatch produces
the `JSONDecodeError` documented above — empty stdin, not a busy mount — so
if you're hitting that error instead, treat it as Root Cause 1 up top, not
this section.

### Fix — recover a currently stuck host

```bash
sudo ./scripts/fix-stuck-containerd-mount.sh
```

This lazy-unmounts (`umount -l`) any leftover `/tmp/containerd-mount*`
targets, then restarts `containerd` and `docker` cleanly. Run it on the
Docker host, not inside a container.

### Fix — prevent recurrence

1. **Install the prune timer** so exited analyzer containers (and their
   mounts) don't accumulate between runs:
   ```bash
   sudo cp systemd/docker-prune.service systemd/docker-prune.timer /etc/systemd/system/
   # edit the ExecStart path in docker-prune.service to your actual clone path first
   sudo systemctl daemon-reload
   sudo systemctl enable --now docker-prune.timer
   ```
2. **If `journalctl -k` confirms OOM kills**: on a 16GB host, the compose
   file's `deploy.resources.limits.memory` ceilings total
   Cassandra 3G + Elasticsearch 3G + TheHive 3G + Cortex 2G + Nginx 0.5G =
   **11.5G**, leaving **~4.5G** (not ~2G) for the OS, the Docker/containerd
   daemons, and the 4 concurrent analyzer containers — recompute this
   yourself with `free -h` before trusting either number, since ES/Cassandra
   JVMs sitting near their `-Xmx` ceiling under load can eat into that
   headroom before the analyzers even start. If `docker stats` at the time
   of failure shows the host genuinely out of headroom when 4 analyzers run
   together, reduce concurrency first (Cortex UI → Organization → Analyzers
   → cap concurrent jobs, or stagger the 4 analyzers instead of firing them
   in parallel) before concluding you need a second host — a config change
   is cheaper to try and reverse than a topology change.

---

## OTXQuery fails intermittently with "API Error! Please verify data type is correct"

### Symptom

The `OTXQuery_2_0` analyzer job fails with the generic message:

```
API Error! Please verify data type is correct.
```

...for what looks like unrelated inputs, sometimes succeeding on a retry
with no config change.

### Root cause

This is a known, unfixed **upstream bug in the analyzer itself**
(`TheHive-Project/Cortex-Analyzers`), not something fixable in this repo.
The analyzer wraps almost every failure — bad API key, network/proxy
issue, an actual bad data type, an AlienVault OTX API change — in this
same generic string, so the message text tells you nothing about the real
cause. See upstream issues
[#22](https://github.com/TheHive-Project/Cortex-Analyzers/issues/22)
(error handling is too generic by design),
[#363](https://github.com/TheHive-Project/Cortex-Analyzers/issues/363)
(same message on IP address submission), and
[#850](https://github.com/TheHive-Project/Cortex-Analyzers/issues/850)
(analyzer breaking again after a Python 3 migration).

**Don't trust the message text.** Check instead:

```bash
# 1. Connectivity from the Cortex host to the OTX API
docker exec cortex curl -I https://otx.alienvault.com

# 2. Is the API key actually populated (not blank)?
#    Cortex UI > Organization > Analyzers > OTXQuery_2_0 > Options
#    There is no supported way to read analyzer config via curl without
#    first creating a Cortex API key in the UI (Organization > API keys);
#    with one, GET {CORTEX_URL}/api/organization/analyzer/OTXQuery_2_0
#    with `Authorization: Bearer <key>` returns the configuration, but the
#    UI check above is simpler and doesn't require issuing a key just to
#    look.

# 3. Raw logs around the failing job
docker compose logs cortex | grep -i otx | tail -30
```

If connectivity is fine and the key is populated, this is very likely the
upstream generic-error-message bug — re-running the same job is a
legitimate diagnostic step here (unlike most flaky-looking failures),
since a transient network blip and a real config problem produce the
identical message.

---

## Nginx exits immediately on startup

SSL certificate files are missing. Generate them first:

```bash
./scripts/generate-self-signed-certs.sh
docker compose restart nginx
```
