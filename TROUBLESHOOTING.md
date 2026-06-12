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

## Nginx exits immediately on startup

SSL certificate files are missing. Generate them first:

```bash
./scripts/generate-self-signed-certs.sh
docker compose restart nginx
```
