# Static TaskBoard UI served by nginx, which also reverse-proxies
# /api/ to the API service. The server block is an envsubst template
# (see default.conf.template) so the same image runs everywhere:
#   docker compose / k8s: PORT=8080, API_SCHEME=http, API_HOST=taskboard-api:3000
#   Render:             PORT=<platform port>, API_SCHEME=https, API_HOST=<api hostname>
#
# Base: nginxinc/nginx-unprivileged (verified tag on Docker Hub 2026-11-03)
# runs as the unprivileged `nginx` user and listens on 8080 by default —
# the official nginx image runs as ROOT and is rejected by Kyverno's
# require-pod-security policy on the ShipIt cluster. Everything the
# official image does (envsubst of /etc/nginx/templates/*.template at
# container start) works identically here; just never bind below 1024.
FROM nginxinc/nginx-unprivileged:1.27-alpine

# Refresh fixable OS packages: the pinned base (2025-06) predates many
# alpine security updates. A full upgrade is safe here — the image is
# just nginx + a static file. Keeps the Trivy HIGH/CRITICAL gate green.
RUN apk update && apk upgrade && rm -rf /var/cache/apk/*

# In-cluster defaults (ShipIt/k8s). Override per environment via env vars.
ENV PORT=8080 \
    API_SCHEME=http \
    API_HOST=taskboard-api:3000

COPY default.conf.template /etc/nginx/templates/default.conf.template
COPY index.html /usr/share/nginx/html/index.html

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget -qO- http://127.0.0.1:${PORT:-8080}/healthz >/dev/null 2>&1 || exit 1
