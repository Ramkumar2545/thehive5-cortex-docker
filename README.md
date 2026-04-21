# TheHive 5 + Cortex 4 Docker Stack

Single-node Docker Compose deployment for **TheHive 5.6.0** and **Cortex 4.0.0**, tuned for a **16 GB RAM** development/lab server.

This repository gives you a practical local or VM-based deployment with:
- Cassandra 4.1.10
- Elasticsearch 8.19.11
- TheHive 5.6.0
- Cortex 4.0.0
- Nginx 1.29.5

## What you must modify

Before starting the stack, you **must** edit these files.

### 1) `.env`
Create `.env` from `.env.example`.

```bash
cp .env.example .env
```

Update these values:

- `UID` → your Linux user id from `id -u`
- `GID` → your Linux group id from `id -g`
- `ELASTICSEARCH_PASSWORD` → set a strong password, this is used by TheHive and Cortex to connect to Elasticsearch
- `CORTEX_DOCKER_JOB_DIRECTORY` → keep default unless you want a different host path for analyzer jobs
- `NGINX_SERVER_NAME` → your hostname or IP, use `localhost` only for local testing
- `NGINX_SSL_TRUSTED_CERTIFICATE` → path used by nginx for trusted CA chain; if using self-signed local testing, you can keep the default placeholder style and adjust after generating certs
- `THEHIVE_SECRET` → long random secret string for Play framework
- `CORTEX_SECRET` → long random secret string for Play framework

Example commands:

```bash
id -u
id -g
openssl rand -base64 48
openssl rand -base64 48
```

### 2) `thehive/config/index.conf`
This file is created from `thehive/config/index.conf.template`.

You must replace:
- `###CHANGEME_ELASTICSEARCH_PASSWORD###`

with the same password you set in `.env` for `ELASTICSEARCH_PASSWORD`.

### 3) `cortex/config/index.conf`
This file is created from `cortex/config/index.conf.template`.

You must replace:
- `###CHANGEME_ELASTICSEARCH_PASSWORD###`

with the same password you set in `.env` for `ELASTICSEARCH_PASSWORD`.

### 4) `thehive/config/secret.conf`
This file is created from `thehive/config/secret.conf.template`.

You must replace:
- `###CHANGEME_THEHIVE_SECRET###`

with the same secret value you set in `.env` as `THEHIVE_SECRET`.

### 5) `cortex/config/secret.conf`
This file is created from `cortex/config/secret.conf.template`.

You must replace:
- `###CHANGEME_CORTEX_SECRET###`

with the same secret value you set in `.env` as `CORTEX_SECRET`.

### 6) TLS certificate files for nginx
If you want HTTPS through nginx, add these files inside `nginx/certs/`:

- `thehive.crt`
- `thehive.key`
- optionally your CA file if your cert chain requires it

If you do not want nginx initially, you can still access:
- TheHive directly on `http://HOST:9000/thehive`
- Cortex directly on `http://HOST:9001/cortex`

## What each config file does

### `docker-compose.yml`
This is the main stack definition.

It controls:
- container images and versions
- memory allocation
- healthchecks
- exposed ports
- mounted directories
- container dependencies

### `thehive/config/application.conf`
This controls TheHive application behavior.

Important values already set:
- Cassandra backend = `cql`
- Cassandra hostname = `cassandra`
- attachment storage = local filesystem
- context path = `/thehive`
- Cortex connector module enabled
- MISP connector module enabled

Only change this if you know exactly why you need a different database, storage, or URL context.

### `cortex/config/application.conf`
This controls Cortex behavior.

Important values already set:
- context path = `/cortex`
- local auth enabled
- analyzer and responder URLs configured
- trusted proxy settings enabled for reverse proxy usage

Only change this if you need LDAP/AD auth or custom analyzer locations.

### `nginx/templates/default.conf.template`
This is the reverse proxy config.

It forwards:
- `/thehive/` → TheHive
- `/cortex/` → Cortex

Change it only if:
- your domain name changes
- you want plain HTTP instead of HTTPS
- you use a different certificate naming scheme

## Recommended server prerequisites

Run these before startup:

```bash
sudo sysctl -w vm.max_map_count=262144
echo 'vm.max_map_count=262144' | sudo tee /etc/sysctl.d/99-thehive.conf
sudo sysctl --system
```

Install Docker and Compose plugin if not already installed.

## First-time setup steps

### 1) Clone repo

```bash
git clone https://github.com/Ramkumar2545/thehive5-cortex-docker.git
cd thehive5-cortex-docker
```

### 2) Prepare files

```bash
chmod +x scripts/*.sh
./scripts/init.sh
```

This script creates:
- `.env` if missing
- required directories
- `thehive/config/index.conf`
- `cortex/config/index.conf`
- `thehive/config/secret.conf`
- `cortex/config/secret.conf`

### 3) Edit generated files

Open and edit:

```bash
nano .env
nano thehive/config/index.conf
nano cortex/config/index.conf
nano thehive/config/secret.conf
nano cortex/config/secret.conf
```

### 4) Optional certificate generation

If you want local self-signed TLS for nginx:

```bash
./scripts/generate-self-signed-certs.sh
```

Then update `.env` if needed.

### 5) Pull and start

```bash
./scripts/start.sh
```

### 6) Verify health

```bash
docker compose ps
./scripts/healthcheck.sh
```

### 7) Follow logs if needed

```bash
docker compose logs -f elasticsearch
docker compose logs -f cassandra
docker compose logs -f thehive
docker compose logs -f cortex
```

## Memory sizing guidance for 16 GB host

This stack is tuned approximately like this:
- Cassandra heap around 2 GB
- Elasticsearch heap 2 GB
- TheHive heap 2 GB
- Cortex heap 1 GB
- remaining RAM left for OS, Docker engine, file cache, and Cortex analyzer containers

If analyzers are heavy, do not reduce the remaining free RAM too aggressively.

## Direct URLs

Without nginx:
- TheHive: `http://YOUR-IP:9000/thehive`
- Cortex: `http://YOUR-IP:9001/cortex`

With nginx and certificates:
- TheHive: `https://YOUR-DOMAIN/thehive/`
- Cortex: `https://YOUR-DOMAIN/cortex/`

## Common mistakes to avoid

- Using different Elasticsearch passwords in `.env`, `thehive/config/index.conf`, and `cortex/config/index.conf`
- Forgetting to replace secret placeholders in `secret.conf`
- Starting Elasticsearch without setting `vm.max_map_count`
- Using wrong `UID` and `GID`, which causes permission problems on mounted volumes
- Assuming nginx is mandatory; it is optional for first local testing
- Forgetting that Cortex needs `/var/run/docker.sock` mounted to run analyzers

## Recommended first login flow

1. Start the stack.
2. Open TheHive first.
3. Open Cortex second.
4. Complete each application’s initial admin setup in browser.
5. Then configure Cortex organization, analyzers, and API integration from TheHive side.

## Useful commands

```bash
# Start
./scripts/start.sh

# Stop
./scripts/stop.sh

# Restart
docker compose restart

# Status
docker compose ps

# Logs
docker compose logs -f thehive
docker compose logs -f cortex

# Recreate everything without deleting config files
docker compose down
docker compose up -d --force-recreate
```

## Source references

This setup was based on these upstream projects:
- https://github.com/StrangeBeeCorp/docker
- https://github.com/TheHive-Project/Cortex
