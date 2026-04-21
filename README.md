# TheHive 5 + Cortex 4 Docker Stack

Single-node Docker Compose deployment for **TheHive 5.6.0** and **Cortex 4.0.0**, sized for a **16 GB RAM** development/lab server.

This stack is based on StrangeBee's official Docker layout and uses:
- Cassandra 4.1.10
- Elasticsearch 8.19.11
- TheHive 5.6.0
- Cortex 4.0.0
- Nginx 1.29.5

## Architecture

Services included:
- Cassandra
- Elasticsearch
- TheHive
- Cortex
- Nginx

Ports:
- TheHive: `9000`
- Cortex: `9001`
- Nginx HTTPS: `443`

## Host sizing

Recommended for this stack:
- RAM: 16 GB
- CPU: 4 vCPU minimum
- Disk: 80 GB+ SSD
- OS: Ubuntu 22.04/24.04 LTS

## Quick start

```bash
git clone https://github.com/Ramkumar2545/thehive5-cortex-docker.git
cd thehive5-cortex-docker
cp .env.example .env
```

Edit `.env` and set:
- `UID`
- `GID`
- `ELASTICSEARCH_PASSWORD`
- `CORTEX_DOCKER_JOB_DIRECTORY`
- `NGINX_SERVER_NAME`
- `NGINX_SSL_TRUSTED_CERTIFICATE`
- `THEHIVE_SECRET`
- `CORTEX_SECRET`

Then create secrets and configs:

```bash
mkdir -p thehive/config cortex/config
cp thehive/config/secret.conf.template thehive/config/secret.conf
cp cortex/config/secret.conf.template cortex/config/secret.conf
cp thehive/config/index.conf.template thehive/config/index.conf
cp cortex/config/index.conf.template cortex/config/index.conf
```

Replace the placeholders:
- `###CHANGEME_ELASTICSEARCH_PASSWORD###`
- `###CHANGEME_THEHIVE_SECRET###`
- `###CHANGEME_CORTEX_SECRET###`

Create folders and start:

```bash
chmod +x scripts/*.sh
docker compose pull
docker compose up -d
```

Check health:

```bash
docker compose ps
docker compose logs -f thehive
docker compose logs -f cortex
```

## Memory profile

This repo is tuned for around 16 GB total host memory:
- Cassandra heap: 2G
- Elasticsearch heap: 2G
- TheHive heap: 2G
- Cortex heap: 1G
- Remaining RAM reserved for Docker, filesystem cache, OS, and analysis jobs

## Important notes

- Cortex mounts `/var/run/docker.sock` so analyzers can run Docker jobs.
- TheHive runs under `/thehive` context path.
- Cortex runs under `/cortex` context path.
- Elasticsearch security is enabled.
- Nginx is included as reverse proxy, but TheHive and Cortex are also exposed directly on 9000/9001 for development.

## Troubleshooting

### vm.max_map_count

```bash
sudo sysctl -w vm.max_map_count=262144
echo 'vm.max_map_count=262144' | sudo tee /etc/sysctl.d/99-thehive.conf
sudo sysctl --system
```

### File ownership

Set your numeric user/group IDs in `.env`:

```bash
id -u
id -g
```

### Common logs

```bash
docker compose logs -f elasticsearch
docker compose logs -f cassandra
docker compose logs -f thehive
docker compose logs -f cortex
```

## Source references

This setup was derived from:
- https://github.com/StrangeBeeCorp/docker
- https://github.com/TheHive-Project/Cortex
