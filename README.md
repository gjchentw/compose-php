# compose-php

A lightweight, production-ready Docker setup for running PHP applications (Laravel-ready).
This repository provides:

- A multi-stage Dockerfile with s6-overlay and PHP-FPM + Nginx.
- A docker-compose setup for quick local development and deployment.
- A convenience `laravel-setup` service to install dependencies and generate Laravel keys.

## Quick start (local)

1. Copy the example env and edit as needed:

```bash
cp .env.example .env.compose
# edit .env.compose: APP_URL, DB_HOST, DB_USER, etc.
```

1. Build and start the services:

```bash
docker compose up -d
```

1. Install frontend assets (if applicable) on the host:

```bash
npm install
npm run dev   # or npm run build / npm run prod
```

Visit [http://localhost](http://localhost) (or the URL set in `APP_URL`) to see your app.

## Deployment tour (what runs where)

Files to know:

- `Dockerfile` — multi-stage image with s6, PHP-FPM, and Nginx configured for production.
- `docker-compose.yaml` — defines two services:

  - `laravel-setup`: one-shot helper to composer install and generate app key (named `app-setup`).

  - `app`: the long-running web service that serves your PHP app (named `app`).
- `cont-init.d/` and `s6-overlay/` — container init scripts and service definitions used by s6.

Service responsibilities:

- `app` (container name `app`):

  - Runs `s6-overlay` as PID 1 to supervise services (nginx, php-fpm, cron, etc).

  - Exposes port 80 and mounts your project at `/app`.

  - Reads runtime configuration from `.env.compose` (passed via `env_file`).

- `laravel-setup`:

  - Temporary container used to run Composer, prepare storage folders, and generate `APP_KEY`.

  - This container mounts your code so generated assets and `.env` changes persist on the host.

How the build works:

- Build context is the repository root. The `Dockerfile` installs packages, extracts s6-overlay, and sets up PHP-FPM and Nginx configuration, then sets `/init` as entrypoint (s6).
- A `VOLUME /app` is declared so your project sources are mounted at runtime by docker-compose.

## System operations (day-to-day commands)

Start the app (build if missing):

```bash
# builds only the first time or when the image changes
docker compose up -d
```

Rebuild images (force rebuild `app`):

```bash
docker compose up -d --no-deps --build app
```

Run the setup helper (run composer & generate key):

```bash
docker compose run --rm laravel-setup
```

Run Artisan inside the running `app` container:

```bash
docker exec -it -w /app app php artisan migrate --force
```

Run non-interactive cronized Artisan tasks from host crontab (example):

```cron
*/5 * * * * docker exec -w /app app php artisan schedule:run >> /var/log/laravel-schedule.log 2>&1
```

Stop / restart:

```bash
docker stop app
docker start app
# or restart
docker restart app
```

Bring everything down (removes containers created by compose):

```bash
docker compose down
```

Inspect logs:

```bash
# service logs (docker-compose)
docker compose logs -f app
# or docker logs
docker logs -f app
```

Copy files into the app container (when needed):

```bash
docker cp localfile app:/app/path
```

Tip: mounting the host project into the container (`- ./app:/app`) means file permissions matter.
If you run into permission issues for `storage`/`bootstrap/cache`, use the `laravel-setup` job to set writable permissions:

```bash
docker compose run --rm laravel-setup
```
