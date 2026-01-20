# Frappe Docker

[![Build Stable](https://github.com/frappe/frappe_docker/actions/workflows/build_stable.yml/badge.svg)](https://github.com/frappe/frappe_docker/actions/workflows/build_stable.yml)
[![Build Develop](https://github.com/frappe/frappe_docker/actions/workflows/build_develop.yml/badge.svg)](https://github.com/frappe/frappe_docker/actions/workflows/build_develop.yml)

Docker images and orchestration for Frappe applications.

## What is this?

This repository handles the containerization of the Frappe stack, including the application server, database, Redis, and supporting services. It provides quick disposable demo setups, a development environment, production-ready Docker images and compose configurations for deploying Frappe applications including ERPNext.

## Repository Structure

```
frappe_docker/
├── docs/                 # Complete documentation
├── overrides/            # Docker Compose configurations for different scenarios
├── compose.yaml          # Base Compose File for production setups
├── pwd.yml               # Single Compose File for quick disposable demo
├── images/               # Dockerfiles for building Frappe images
├── development/          # Development environment configurations
├── devcontainer-example/ # VS Code devcontainer setup
└── resources/            # Helper scripts and configuration templates
```

> This section describes the structure of **this repository**, not the Frappe framework itself.

### Key Components

- `docs/` - Canonical documentation for all deployment and operational workflows
- `overrides/` - Opinionated Compose overrides for common deployment patterns
- `compose.yaml` - Base compose file for production setups (production)
- `pwd.yml` - Disposable demo environment (non-production)

## Documentation

**The official documentation for `frappe_docker` is maintained in the `docs/` folder in this repository.**

**New to Frappe Docker?** Read the [Getting Started Guide](docs/getting-started.md) for a comprehensive overview of repository structure, development workflow, custom apps, Docker concepts, and quick start examples.

If you are already familiar with Frappe, you can jump right into the [different deployment methods](docs/01-getting-started/01-choosing-a-deployment-method.md) and select the one best suited to your use case.

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/)
- [Docker Compose v2](https://docs.docker.com/compose/)
- [git](https://docs.github.com/en/get-started/getting-started-with-git/set-up-git)

> For Docker basics and best practices refer to Docker's [documentation](http://docs.docker.com)

## Demo setup

The fastest way to try Frappe is to play in an already set up sandbox, in your browser, click the button below:

<a href="https://labs.play-with-docker.com/?stack=https://raw.githubusercontent.com/frappe/frappe_docker/main/pwd.yml">
  <img src="https://raw.githubusercontent.com/play-with-docker/stacks/master/assets/images/button.png" alt="Try in PWD"/>
</a>

### Try on your environment

> **⚠️ Disposable demo only**
>
> **This setup is intended for quick evaluation. Expect to throw the environment away.** You will not be able to install custom apps to this setup. For production deployments, custom configurations, and detailed explanations, see the full documentation.

First clone the repo:

```sh
git clone https://github.com/frappe/frappe_docker
cd frappe_docker
```

Then run:

```sh
docker compose -f pwd.yml up -d
```

Wait for a couple of minutes for ERPNext site to be created or check `create-site` container logs before opening browser on port `8080`. (username: `Administrator`, password: `admin`)

## Documentation Links

### [Getting Started Guide](docs/getting-started.md)

### [Frequently Asked Questions](https://github.com/frappe/frappe_docker/wiki/Frequently-Asked-Questions)

### [Getting Started](#getting-started)

### [Deployment Methods](docs/01-getting-started/01-choosing-a-deployment-method.md)

### [ARM64](docs/01-getting-started/03-arm64.md)

### [Container Setup Overview](docs/02-setup/01-overview.md)

### [Development](docs/05-development/01-development.md)

## Contributing

Contributions are welcome! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

This repository is only for container related stuff. You also might want to contribute to:

## Resources

- [Frappe framework](https://github.com/frappe/frappe),
- [ERPNext](https://github.com/frappe/erpnext),
- [Frappe Bench](https://github.com/frappe/bench).

## Development setup (Bamboi-tech fork)

Create host directories for bind mounts (one time):

```bash
mkdir -p ./frappe-local/{apps,sites,logs,gitops}
```

### Folder layout

Make sure the frappe_docker is inside the frappe_local directory.

```bash
cd ./frappe-local
git clone https://github.com/Bamboi-tech/frappe_docker
cd frappe_docker
cp example.env .env
```

Local dev env vars (**example**):

```plaintext
SITES=dev.localhost
PULL_POLICY=always
# absolute path of your local monorepo root
PROJECT_ROOT=<path-to>/frappe-local
```

Render compose to ../gitops with overrides, then up:

```bash
cd <path-to>/frappe-local

docker compose -f frappe_docker/compose.yaml \
  -f frappe_docker/overrides/compose.mariadb.yaml \
  -f frappe_docker/overrides/compose.redis.yaml \
  -f frappe_docker/overrides/compose.assets.volume.yaml \
  -f frappe_docker/overrides/compose.platform.arm64.yaml \
  -f frappe_docker/overrides/compose.ports.yaml \
  config > gitops/docker-compose.yml

docker compose -p frappe-local -f gitops/docker-compose.yml up -d --force-recreate
```

If you want to develop kn_integration locally add these to the docker-compose.yml as well:

```bash
  -f frappe_docker/overrides/compose.kn-only.yaml \
  -f frappe_docker/overrides/compose.sftp.local.yaml \
```

When editing apps locally, ensure apps.txt exists (bind-mounts hide the image default)

```bash
mkdir -p <path-to>/frappe-local/sites
printf "frappe\nerpnext\n" > <path-to>/frappe-local/sites/apps.txt
```

Ensure common_site_config.json exists inside /sites

```json
{
 "asset_version": "1762777856",
 "db_host": "db",
 "db_port": 3306,
 "developer_mode": 1,
 "file_watcher_port": 6787,
 "kn_sftp_key_path": "/home/frappe/.ssh/kn_mft_test_ed25519",
 "mute_emails": 1,
 "redis_cache": "redis://redis-cache:6379",
 "redis_queue": "redis://redis-queue:6379",
 "redis_socketio": "redis://redis-queue:6379",
 "socketio_port": 9000
}
```

Create the site (dev.localhost)

```bash
docker compose -p frappe-local exec backend bash -lc '
  cd /home/frappe/frappe-bench
  bench new-site dev.localhost \
    --mariadb-user-host-login-scope=% \
    --db-root-password 123 \
    --admin-password admin
'
```

If an error occurred you wont be able to create the site twice so this command will remove the site first:

```bash
docker-compose -p frappe-local exec backend bash -lc 'cd /home/frappe/frappe-bench && bench drop-site dev.localhost --force'
```

Install apps for local dev (bind-mount workflow)

- Because overrides/compose.kn-only.yaml makes `apps/kn_integration` bind-mounted, a clone of the app will appear under `<path-to>/frappe-local/apps/kn_integration` so you can edit locally.


```bash
git clone git@github.com:Bamboi-tech/kn_integration.git <path-to>/frappe-local/apps/kn_integration
docker compose -p frappe-local exec backend bench --site dev.localhost install-app kn_integration
```

Zsh helper to rebuild/sync assets (subshell-safe)

- Add to your `~/.zshrc`, then `source ~/.zshrc`. Running in a subshell prevents your interactive shell from closing due to `-euo pipefail`.
- COMPOSE_FILE might be a different path for you. change if necessary.

```bash
frappe_assets_sync() (
  set -euo pipefail

  PROJECT=${1:-frappe-local}
  COMPOSE_FILE="${2:-$HOME/frappe-local/gitops/docker-compose.yml}"
  SITE=${3:-dev.localhost}

  docker compose -p "$PROJECT" -f "$COMPOSE_FILE" exec backend bash -lc "
    set -e
    cd /home/frappe/frappe-bench
    NODEBIN=\$(ls -d /home/frappe/.nvm/versions/node/*/bin | head -n1); export PATH=\"\$NODEBIN:\$PATH\"
    bench --site $SITE migrate
    bench build --force
    for app in \$(cat sites/apps.txt); do
      [ -d apps/\$app/\$app/public ] || continue
      src=\"apps/\$app/\$app/public\"; dst=\"sites/assets/\$app\"
      rm -rf \"\$dst\"; mkdir -p \"\$dst\"; cp -a \"\$src/.\" \"\$dst/\"
    done
    bench set-config -g asset_version \$(date +%s)
    bench --site $SITE clear-website-cache
    bench --site $SITE clear-cache
  "

  docker compose -p "$PROJECT" -f "$COMPOSE_FILE" restart backend frontend

  docker compose -p "$PROJECT" -f "$COMPOSE_FILE" exec backend  md5sum sites/assets/assets.json
  docker compose -p "$PROJECT" -f "$COMPOSE_FILE" exec frontend md5sum sites/assets/assets.json

  HASH=$(docker compose -p "$PROJECT" -f "$COMPOSE_FILE" exec -T backend bash -lc \
    "grep -o 'desk.bundle.[A-Z0-9]\\+\\.css' sites/assets/assets.json | tail -n1" | tr -d $'\r')
  echo "CSS hash: $HASH"
  docker compose -p "$PROJECT" -f "$COMPOSE_FILE" exec backend  bash -lc "ls -l sites/assets/frappe/dist/css/$HASH"
  docker compose -p "$PROJECT" -f "$COMPOSE_FILE" exec frontend bash -lc "ls -l sites/assets/frappe/dist/css/$HASH"
)
```

## Production (VM) setup

Env (example):

```plaintext
SITES=erp.bamboi.eu
LETSENCRYPT_EMAIL=tools@bamboi.eu
CUSTOM_IMAGE=custom
CUSTOM_TAG=15
PULL_POLICY=never
```

Build custom image from apps.json:
:heavy_exclamation_mark: This step takes longer the more apps are in apps.json :heavy_exclamation_mark: Make sure that for every app you also have the required apps. To find required apps go to repo and search "required_apps".
:heavy_exclamation_mark: Also prune docker builder and image to make sure there is enough space. :heavy_exclamation_mark:

<!-- TODO: --no-cache is used because the apps.json is following branches like main and develop instead of tags
deprecate using ecommerce integrations -->
```bash
docker builder prune -af
docker image prune -af

export APPS_JSON_BASE64=$(base64 -w 0 apps.json)
docker build --no-cache \
  --platform linux/amd64 \
  --build-arg=FRAPPE_PATH=https://github.com/frappe/frappe \
  --build-arg=FRAPPE_BRANCH=version-15 \
  --build-arg=APPS_JSON_BASE64=$APPS_JSON_BASE64 \
  --tag=frappe/erpnext:v15.94.3 \
  --file=images/custom/Containerfile .
```

Render compose with HTTPS and shared assets, then up:

```bash
mkdir -p ~/gitops
docker compose -f compose.yaml \
  -f overrides/compose.mariadb.yaml \
  -f overrides/compose.redis.yaml \
  -f overrides/compose.https-dynamic.yaml \
  -f overrides/compose.assets.volume.yaml \
  -f overrides/compose.sftp.prod.yaml \
  config > ~/gitops/docker-compose.yml

docker compose -p erpnext-vm-bamboi -f ~/gitops/docker-compose.yml up -d --force-recreate
```

Create the site (erp.bamboi.eu) (only once)

```bash
docker compose -p erpnext-vm-bamboi exec backend bash -lc '
  cd /home/frappe/frappe-bench
  bench new-site erp.bamboi.eu \
    --mariadb-user-host-login-scope=% \
    --db-root-password 123 \
    --admin-password admin
'
```

### (Un)install apps from apps.json on the VM

```bash
DC='docker compose -p erpnext-vm-bamboi -f /home/olivierguntenaar/gitops/docker-compose.yml'
SITE=erp.bamboi.eu
```

### Optional: confirm it's installed

```bash
$DC exec backend bash -lc "bench --site $SITE list-apps"
```

### Safer: enable maintenance


```bash
$DC exec backend bash -lc "bench --site $SITE set-maintenance-mode on"

```

### (Un)install app

```bash
$DC exec backend bash -lc "bench --site $SITE uninstall-app <app>"
$DC exec backend bash -lc "bench --site $SITE install-app <app>"
```

### Finish up

```bash
$DC exec backend bash -lc "bench --site $SITE migrate"
$DC exec backend bash -lc "bench --site $SITE set-maintenance-mode off"
$DC exec backend bash -lc "bench --site $SITE clear-cache && bench --site $SITE clear-website-cache"
$DC restart backend frontend
```

### Verify it's gone

```bash
$DC exec backend bash -lc "bench --site $SITE list-apps"
```
## License

This repository is licensed under the MIT License. See [LICENSE](LICENSE) for details.
