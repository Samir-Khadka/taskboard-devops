# Static TaskBoard UI served by nginx, which also reverse-proxies
# /api/ and /metrics to the API service. The server block is an
# envsubst template (see default.conf.template) so the same image runs
# under docker compose (API at api:3000) and on Render (API over https).
FROM nginx:1.27-alpine

COPY default.conf.template /etc/nginx/templates/default.conf.template
COPY index.html /usr/share/nginx/html/index.html

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget -qO- http://127.0.0.1:${PORT:-80}/healthz >/dev/null 2>&1 || exit 1
