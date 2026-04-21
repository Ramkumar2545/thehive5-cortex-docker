# TheHive 5 + Cortex 4 — Docker Development Stack

Single-node Docker Compose deployment for **TheHive 5.6.0** and **Cortex 4.0.0**, tuned for a **16 GB RAM** development/lab server.

| Service | Image | Version |
|---|---|---|
| Cassandra | cassandra | 4.1.10 |
| Elasticsearch | elasticsearch | 8.19.11 |
| TheHive | strangebee/thehive | 5.6.0 |
| Cortex | thehiveproject/cortex | 4.0.0 |
| Nginx | nginx | 1.29.5 |

---

## Quick-start (TL;DR)

```bash
# 1. Clone
git clone https://github.com/Ramkumar2545/thehive5-cortex-docker.git
cd thehive5-cortex-docker

# 2. Kernel setting required by Elasticsearch
sudo sysctl -w vm.max_map_count=262144
echo 'vm.max_map_count=262144' | sudo tee /etc/sysctl.d/99-thehive.conf

# 3. Copy all templates to live config files
chmod +x scripts/*.sh
./scripts/init.sh

# 4. Edit the 5 files listed in the checklist printed above

# 5. Fix directory ownership before first start
docker compose down
chmod -R 777 cortex/ thehive/ elasticsearch/ cassandra/ nginx/

# Cortex
chown -R 1000:1000 cortex/cortex-jobs cortex/logs cortex/neurons cortex/config
chmod -R 777 cortex/cortex-jobs
chmod -R 755 cortex/logs cortex/neurons cortex/config

# TheHive
chown -R 1000:1000 thehive/data thehive/logs thehive/config
chmod -R 755 thehive/data thehive/logs thehive/config

# Cassandra
chown -R 999:999 cassandra/data cassandra/logs
chmod -R 755 cassandra/data cassandra/logs

# Elasticsearch
chown -R 1000:1000 elasticsearch/data elasticsearch/logs
chmod -R 755 elasticsearch/data elasticsearch/logs

# Nginx
chmod -R 755 nginx/certs nginx/templates


# 6. Start
docker compose pull
Generate self-signed certs 
./scripts/generate-self-signed-certs.sh
docker compose up -d


# 7. Check
docker compose ps
./scripts/healthcheck.sh
```

---

## What `./scripts/init.sh` does

When you run `init.sh` it automatically runs these copies for you:

```bash
cp .env.example                           .env
cp thehive/config/index.conf.template     thehive/config/index.conf
cp thehive/config/secret.conf.template    thehive/config/secret.conf
cp cortex/config/index.conf.template      cortex/config/index.conf
cp cortex/config/secret.conf.template     cortex/config/secret.conf
```

It then prints a checklist of every placeholder you must replace.

---

## Files you MUST edit after init

### Summary table

| File | Placeholder | Replace with | Notes |
|---|---|---|---|
| `.env` | `ELASTICSEARCH_PASSWORD=ChangeThisElasticPassword123!` | your ES password e.g. `admin!123` | Used by Docker Compose to set the Elasticsearch `elastic` user password |
| `.env` | `THEHIVE_SECRET=ChangeThisTheHiveSecretValue` | output of `openssl rand -base64 48` | Play framework session key, NOT the ES password |
| `.env` | `CORTEX_SECRET=ChangeThisCortexSecretValue` | output of `openssl rand -base64 48` | Play framework session key, NOT the ES password |
| `.env` | `UID=1000` | output of `id -u` | Your Linux user id |
| `.env` | `GID=1000` | output of `id -g` | Your Linux group id |
| `thehive/config/index.conf` | `###CHANGEME_ELASTICSEARCH_PASSWORD###` | **same password** as `ELASTICSEARCH_PASSWORD` in `.env` | Must match exactly |
| `cortex/config/index.conf` | `###CHANGEME_ELASTICSEARCH_PASSWORD###` | **same password** as `ELASTICSEARCH_PASSWORD` in `.env` | Must match exactly |
| `thehive/config/secret.conf` | `###CHANGEME_THEHIVE_SECRET###` | **same value** as `THEHIVE_SECRET` in `.env` | Play secret key |
| `cortex/config/secret.conf` | `###CHANGEME_CORTEX_SECRET###` | **same value** as `CORTEX_SECRET` in `.env` | Play secret key |

---

### Full example with password `admin!123`

#### `.env`
```env
UID=1000
GID=1000
ELASTICSEARCH_PASSWORD=admin!123
CORTEX_DOCKER_JOB_DIRECTORY=/home/thehive/hive/thehive5-cortex-docker/cortex/cortex-jobs
NGINX_SERVER_NAME=localhost
NGINX_SSL_TRUSTED_CERTIFICATE=/etc/nginx/certs/thehive-ca.crt
THEHIVE_SECRET=xK92mZpL3QnRvTwYsAjDgFbHcUoEiNtXyWkO1VhMl
CORTEX_SECRET=aB7nWqRpKsLmXoVtGcYeJfHiUdMzNwTyPbCgFkDsEl
cassandra_image_version=4.1.10
elasticsearch_image_version=8.19.11
thehive_image_version=5.6.0
cortex_image_version=4.0.0
nginx_image_version=1.29.5
```

> ⚠️ Version variables (`cassandra_image_version`, etc.) must be in `.env`.
> Run `cat versions.env >> .env` if they are missing.

#### `thehive/config/index.conf`
```hocon
db.janusgraph.index.search {
  backend = elasticsearch
  hostname = ["elasticsearch"]
  index-name = thehive
  elasticsearch.http.auth {
    type = "basic"
    basic {
      username = "elastic"
      password = "admin!123"   # ← same as ELASTICSEARCH_PASSWORD in .env
    }
  }
}
```

#### `cortex/config/index.conf`
```hocon
search {
  index = cortex
  user = "elastic"
  password = "admin!123"   # ← same as ELASTICSEARCH_PASSWORD in .env
}
```

#### `thehive/config/secret.conf`
```hocon
play.http.secret.key="xK92mZpL3QnRvTwYsAjDgFbHcUoEiNtXyWkO1VhMl"  # ← NOT the ES password
```

#### `cortex/config/secret.conf`
```hocon
play.http.secret.key="aB7nWqRpKsLmXoVtGcYeJfHiUdMzNwTyPbCgFkDsEl"  # ← different from TheHive
```

> ⚠️ The Elasticsearch password must be **identical** across `.env`, `thehive/config/index.conf`, and `cortex/config/index.conf`.

---

## Directory ownership (REQUIRED before first start)

Each container runs as a specific internal UID. Mounted host directories **must** be owned by that UID before startup or the JVM will fail to write logs and crash.

| Container | Internal UID | Directories |
|---|---|---|
| Cassandra | `999` | `cassandra/data`, `cassandra/logs` |
| Elasticsearch | `1000` | `elasticsearch/data`, `elasticsearch/logs` |
| TheHive | `1000` | `thehive/data`, `thehive/logs`, `thehive/config` |
| Cortex | `1000` | `cortex/logs`, `cortex/neurons`, `cortex/cortex-jobs` |

### Run these every time you re-clone or reset volumes

```bash
# Stop all containers first
docker compose down

# Fix ownership
chown -R 1000:1000 thehive/data thehive/logs thehive/config
chown -R 1000:1000 cortex/logs cortex/neurons cortex/cortex-jobs
chown -R 999:999   cassandra/data cassandra/logs
chown -R 1000:1000 elasticsearch/data elasticsearch/logs

# Fix permissions
chmod -R 755 cassandra/data cassandra/logs
chmod -R 755 elasticsearch/data elasticsearch/logs

# Start
docker compose up -d
```

> ⚠️ If you skip this step, Cassandra will crash with:
> `Error opening log file '/opt/cassandra/logs/gc.log': Permission denied`

---

## What each config file does

| File | Purpose | Change it? |
|---|---|---|
| `docker-compose.yml` | Defines all containers, ports, volumes, memory limits, healthchecks | Only if you change ports or memory |
| `thehive/config/application.conf` | TheHive app settings — Cassandra DB, storage, context path, modules | Only if changing DB or storage backend |
| `cortex/config/application.conf` | Cortex app settings — auth, analyzer URLs, proxy settings | Only if adding LDAP/AD auth |
| `thehive/config/index.conf` | Elasticsearch connection for TheHive | Replace password placeholder |
| `cortex/config/index.conf` | Elasticsearch connection for Cortex | Replace password placeholder |
| `thehive/config/secret.conf` | Play framework secret key for TheHive | Replace secret placeholder |
| `cortex/config/secret.conf` | Play framework secret key for Cortex | Replace secret placeholder |
| `nginx/templates/default.conf.template` | Nginx reverse proxy rules | Only if changing domain or TLS setup |

---

## Server prerequisites

```bash
# Required for Elasticsearch
sudo sysctl -w vm.max_map_count=262144
echo 'vm.max_map_count=262144' | sudo tee /etc/sysctl.d/99-thehive.conf
sudo sysctl --system

# Find your UID and GID
id -u
id -g

# Generate secrets
openssl rand -base64 48   # use as THEHIVE_SECRET
openssl rand -base64 48   # use as CORTEX_SECRET
```

---

## Memory profile (16 GB host)

| Container | Heap | Docker limit |
|---|---|---|
| Cassandra | 2 GB | 3 GB |
| Elasticsearch | 2 GB | 3 GB |
| TheHive | 2 GB | 3 GB |
| Cortex | 1 GB | 2 GB |
| Nginx | — | 512 MB |
| OS + Docker + analyzers | remaining ~2 GB | — |

---

## Direct access URLs

| App | Without nginx | With nginx |
|---|---|---|
| TheHive | `http://HOST:9000/thehive` | `https://HOST/thehive/` |
| Cortex | `http://HOST:9001/cortex` | `https://HOST/cortex/` |

---

## Optional: self-signed TLS certificates

```bash
./scripts/generate-self-signed-certs.sh
```

This creates `nginx/certs/thehive.crt`, `thehive.key`, and `thehive-ca.crt`.

---

## Common mistakes

| Mistake | Symptom | Fix |
|---|---|---|
| Different ES passwords across files | TheHive/Cortex restart-loop, auth error in logs | Make all three identical |
| Wrong UID/GID in `.env` | Permission denied on volume mounts | Run `id -u` and `id -g` and update `.env` |
| Missing `vm.max_map_count` | Elasticsearch exits with bootstrap error | Run the sysctl commands above |
| Secret placeholder not replaced | App fails to start, Play config error | Check `secret.conf` in both thehive and cortex |
| nginx cert files missing | Nginx exits immediately | Run `generate-self-signed-certs.sh` or skip nginx for initial test |
| Version variables missing from `.env` | `docker compose pull` fails with blank image reference | Run `cat versions.env >> .env` |
| Cassandra `Permission denied` on gc.log | JVM exits, container restarts in loop | `chown -R 999:999 cassandra/data cassandra/logs && chmod -R 755 cassandra/` |
| Elasticsearch `Permission denied` | ES exits at bootstrap | `chown -R 1000:1000 elasticsearch/data elasticsearch/logs` |

---

## Useful commands

```bash
# Start
./scripts/start.sh

# Stop
./scripts/stop.sh

# Health check
./scripts/healthcheck.sh

# Follow logs
docker compose logs -f elasticsearch
docker compose logs -f cassandra
docker compose logs -f thehive
docker compose logs -f cortex

# Restart a single container
docker compose restart thehive

# Full rebuild without losing config
docker compose down
docker compose up -d --force-recreate
```

---

## First login flow

1. Open `http://HOST:9000/thehive` — complete TheHive admin setup.
2. Open `http://HOST:9001/cortex` — complete Cortex admin setup.
3. In Cortex — create an organisation and generate an API key.
4. In TheHive — add Cortex connector using that API key and `http://cortex:9001`.
5. Enable analyzers and responders from Cortex UI.

---

## Source references

- https://github.com/StrangeBeeCorp/docker
- https://github.com/TheHive-Project/Cortex
