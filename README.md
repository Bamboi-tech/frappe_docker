[![Build Stable](https://github.com/frappe/frappe_docker/actions/workflows/build_stable.yml/badge.svg)](https://github.com/frappe/frappe_docker/actions/workflows/build_stable.yml)
[![Build Develop](https://github.com/frappe/frappe_docker/actions/workflows/build_develop.yml/badge.svg)](https://github.com/frappe/frappe_docker/actions/workflows/build_develop.yml)

Everything about [Frappe](https://github.com/frappe/frappe) and [ERPNext](https://github.com/frappe/erpnext) in containers.

# Getting Started

**New to Frappe Docker?** Read the [Getting Started Guide](docs/getting-started.md) for a comprehensive overview of repository structure, development workflow, custom apps, Docker concepts, and quick start examples.

To get started you need [Docker](https://docs.docker.com/get-docker/), [docker-compose](https://docs.docker.com/compose/), and [git](https://docs.github.com/en/get-started/getting-started-with-git/set-up-git) setup on your machine. For Docker basics and best practices refer to Docker's [documentation](http://docs.docker.com).

Once completed, chose one of the following two sections for next steps.

### Try in Play With Docker

To play in an already set up sandbox, in your browser, click the button below:

<a href="https://labs.play-with-docker.com/?stack=https://raw.githubusercontent.com/frappe/frappe_docker/main/pwd.yml">
  <img src="https://raw.githubusercontent.com/play-with-docker/stacks/master/assets/images/button.png" alt="Try in PWD"/>
</a>

### Try on your Dev environment

First clone the repo:

```sh
git clone https://github.com/frappe/frappe_docker
cd frappe_docker
```

Then run: `docker compose -f pwd.yml up -d`

### To run on ARM64 architecture follow this instructions

After you clone the repo and `cd frappe_docker`, run this command to build multi-architecture images specifically for ARM64.

`docker buildx bake --no-cache --set "*.platform=linux/arm64"`

and then

- add `platform: linux/arm64` to all services in the `pwd.yml`
- replace the current specified versions of erpnext image on `pwd.yml` with `:latest`

Then run: `docker compose -f pwd.yml up -d`

## Final steps

Wait for 5 minutes for ERPNext site to be created or check `create-site` container logs before opening browser on port 8080. (username: `Administrator`, password: `admin`)

If you ran in a Dev Docker environment, to view container logs: `docker compose -f pwd.yml logs -f create-site`. Don't worry about some of the initial error messages, some services take a while to become ready, and then they go away.

# Documentation

### [Getting Started Guide](docs/getting-started.md)

### [Frequently Asked Questions](https://github.com/frappe/frappe_docker/wiki/Frequently-Asked-Questions)

### [Production](#production)

- [List of containers](docs/container-setup/01-overview.md)
- [Single Compose Setup](docs/single-compose-setup.md)
- [Environment Variables](docs/container-setup/env-variables.md)
- [Single Server Example](docs/single-server-example.md)
- [Setup Options](docs/setup-options.md)
- [Site Operations](docs/site-operations.md)
- [Backup and Push Cron Job](docs/backup-and-push-cronjob.md)
- [Port Based Multi Tenancy](docs/port-based-multi-tenancy.md)
- [Migrate from multi-image setup](docs/migrate-from-multi-image-setup.md)
- [running on linux/mac](docs/setup_for_linux_mac.md)
- [TLS for local deployment](docs/tls-for-local-deployment.md)

### [Custom Images](#custom-images)

- [Custom Apps](docs/container-setup/02-build-setup.md)
- [Build Version 10 Images](docs/build-version-10-images.md)

### [Development](#development)

- [Development using containers](docs/development.md)
- [Bench Console and VSCode Debugger](docs/bench-console-and-vscode-debugger.md)
- [Connect to localhost services](docs/connect-to-localhost-services-from-containers-for-local-app-development.md)

### [Troubleshoot](docs/troubleshoot.md)

# Contributing

If you want to contribute to this repo refer to [CONTRIBUTING.md](CONTRIBUTING.md)

This repository is only for container related stuff. You also might want to contribute to:

- [Frappe framework](https://github.com/frappe/frappe#contributing),
- [ERPNext](https://github.com/frappe/erpnext#contributing),
- [Frappe Bench](https://github.com/frappe/bench).

## Development setup (Bamboi-tech fork)

Create host directories for bind mounts (one time):

```bash
mkdir -p ~/frappe-local/{apps,sites,logs,gitops}
```

Clone this repo (fork) and prepare env:

```bash
git clone https://github.com/Bamboi-tech/frappe_docker
cd frappe_docker
cp example.env .env
```

Local dev env vars (example):

```plaintext
SITES=dev.localhost
PULL_POLICY=always
# absolute path of your local monorepo root
PROJECT_ROOT=/Users/<you>/frappe-local
```

Render compose to ../gitops with overrides, then up:

```bash
mkdir -p ../gitops
docker compose -f compose.yaml \
  -f overrides/compose.mariadb.yaml \
  -f overrides/compose.redis.yaml \
  -f overrides/compose.bind-mounts.yaml \
  -f overrides/compose.assets.volume.yaml \
  -f overrides/compose.ports.yaml \
  config > ../gitops/docker-compose.yml

docker compose -p frappe-local -f ../gitops/docker-compose.yml up -d --force-recreate
```

Shared assets volume

- This fork includes `overrides/compose.assets.volume.yaml`, ensuring backend and frontend share `sites/assets` to prevent hashed CSS/JS mismatches. For clarity, the override looks like:

```yaml
services:
  backend:
    volumes:
      - assets:/home/frappe/frappe-bench/sites/assets
  frontend:
    volumes:
      - assets:/home/frappe/frappe-bench/sites/assets:ro
volumes:
  assets:
    name: frappe_docker_assets
```

Install apps for local dev (bind-mount workflow)

- Because `apps/` is bind-mounted, clones will appear under `~/frappe-local/apps/<app>` so you can edit on host.

```bash
docker compose -p frappe-local exec backend bench get-app --branch develop https://github.com/Bamboi-tech/kn_integration
docker compose -p frappe-local exec backend bench --site dev.localhost install-app kn_integration
```

Zsh helper to rebuild/sync assets (subshell-safe)

- Add to your `~/.zshrc`, then `source ~/.zshrc`. Running in a subshell prevents your interactive shell from closing due to `-euo pipefail`.

```bash
frappe_assets_sync() (
  set -euo pipefail

  PROJECT=${1:-frappe-local}
  COMPOSE_FILE="${2:-$HOME/frappe-local/gitops/docker-compose.yml}"
  SITE=${3:-dev.localhost}

  docker compose -p "$PROJECT" -f "$COMPOSE_FILE" exec backend bash -lc "
    set -e
    cd /home/frappe/frappe-bench
    NODEBIN=\$(ls -d /home/frappe/.nvm/versions/node/*/bin | head -n1); export PATH=\"$NODEBIN:$PATH\"
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

Optional: Local VM-style build (apps.json)

- You can mirror the VM flow locally (build image). You can still include bind-mounts to override a baked app while developing.
- macOS-safe base64:

```bash
export APPS_JSON_BASE64="$(base64 < apps.json | tr -d '\n')"
```

- GNU/Linux:

```bash
export APPS_JSON_BASE64=$(base64 -w 0 apps.json)
```

- Build:

```bash
docker build \
  --build-arg=FRAPPE_PATH=https://github.com/frappe/frappe \
  --build-arg=FRAPPE_BRANCH=version-15 \
  --build-arg=APPS_JSON_BASE64=$APPS_JSON_BASE64 \
  --tag=custom:15 \
  --file=images/custom/Containerfile .
```

- In `.env` set:

```plaintext
SITES=dev.localhost
CUSTOM_IMAGE=custom
CUSTOM_TAG=15
PULL_POLICY=never
PROJECT_ROOT=/Users/<you>/frappe-local
```

- If you want live edits, include `overrides/compose.bind-mounts.yaml` too; otherwise omit it to test the baked image only.

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

```bash
export APPS_JSON_BASE64=$(base64 -w 0 apps.json)
docker build \
  --build-arg=FRAPPE_PATH=https://github.com/frappe/frappe \
  --build-arg=FRAPPE_BRANCH=version-15 \
  --build-arg=APPS_JSON_BASE64=$APPS_JSON_BASE64 \
  --tag=custom:15 \
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
  config > ~/gitops/docker-compose.yml

docker compose -p erpnext-vm-bamboi -f ~/gitops/docker-compose.yml up -d --force-recreate
```

Zsh helper (VM defaults):
Zsh helper to rebuild/sync assets (subshell-safe)

- Add to your `~/.zshrc`, then `source ~/.zshrc`. Running in a subshell prevents your interactive shell from closing due to `-euo pipefail`.


```bash
frappe_assets_sync_vm() (
  set -euo pipefail

  PROJECT=${1:-erpnext-vm-bamboi}
  COMPOSE_FILE="${2:-$HOME/gitops/docker-compose.yml}"
  SITE=${3:-erp.bamboi.eu}

  docker compose -p "$PROJECT" -f "$COMPOSE_FILE" exec backend bash -lc "
    set -e
    cd /home/frappe/frappe-bench
    NODEBIN=\$(ls -d /home/frappe/.nvm/versions/node/*/bin | head -n1); export PATH=\"$NODEBIN:$PATH\"
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

Notes:

- Local uses bind mounts (`overrides/compose.bind-mounts.yaml`) and `PROJECT_ROOT`; VM uses a custom image built from `apps.json`. Both use the shared `assets` volume override to prevent CSS/JS hash mismatches.
- If a repo URL changes but the app’s internal `app_name` stays the same, just update `apps.json` and rebuild/redeploy; the site remains intact.
