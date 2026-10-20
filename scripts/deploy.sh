#!/usr/bin/env bash
# TaskBoard — on-server deploy script.
#
# Run ON the server (by hand or from the CD workflow over SSH):
#   cd ~/taskboard-devops && bash scripts/deploy.sh
#
# Pulls the latest code, refreshes the prebuilt images, rebuilds the app
# images, restarts the stack and waits until it answers healthy.
set -euo pipefail

cd "$(dirname "$0")/.."

echo "==> Pulling latest code"
git pull --ff-only

echo "==> Refreshing base/registry images (db, prometheus, grafana)"
docker compose pull db prometheus grafana || true

echo "==> Building and starting the stack"
docker compose up -d --build

echo "==> Waiting for the web UI on http://localhost:8080/"
for i in $(seq 1 30); do
  if curl -fsS http://localhost:8080/ >/dev/null 2>&1; then
    echo "    web UI is up"
    break
  fi
  if [ "$i" -eq 30 ]; then
    echo "ERROR: web UI did not come up in time" >&2
    docker compose ps >&2 || true
    exit 1
  fi
  sleep 2
done

echo "==> Checking the API health (inside the api container)"
docker compose exec -T api node -e \
  "fetch('http://127.0.0.1:3000/health').then(r => { if (!r.ok) process.exit(1); console.log('    api /health OK'); }).catch(() => process.exit(1))"

echo "==> Stack status"
docker compose ps

echo "Deploy complete."
