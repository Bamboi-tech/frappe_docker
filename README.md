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

docker compose -p frappe-local -f ../gitops/docker-compose.yml up -d --force-recreate
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

```bash
docker builder prune -af
docker image prune -af

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
