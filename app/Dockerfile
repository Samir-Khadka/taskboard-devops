# syntax=docker/dockerfile:1

# Base pinned to an exact patch (verified on Docker Hub 2026-11-03) so
# rebuilds are reproducible and the supply chain is auditable.
# Re-pin deliberately when you want a newer Node, then re-scan.

# ---- Stage 1: install production dependencies -----------------------------
FROM node:20.20.2-alpine AS deps
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --omit=dev --no-audit --no-fund

# ---- Stage 2: slim runtime --------------------------------------------------
FROM node:20.20.2-alpine AS runtime
ENV NODE_ENV=production
WORKDIR /app

# Refresh fixable OS packages: the pinned base (2026-04) predates several
# alpine security updates (openssl). Targeted upgrade only, so the layer
# stays close to the pinned base. Keeps the Trivy HIGH/CRITICAL gate green.
RUN apk update && apk upgrade libcrypto3 libssl3 && rm -rf /var/cache/apk/*

# Copy only what the app needs at runtime.
COPY --from=deps /app/node_modules ./node_modules
COPY package.json ./
COPY src ./src

# npm is only needed at build time (deps stage). Strip its bundled
# node_modules from the runtime image: Trivy flags several HIGH/CRITICAL
# CVEs in npm's own dependencies (tar, pacote, sigstore, ...), none of
# which the app uses at runtime (it runs via `node` directly).
RUN rm -rf /usr/local/lib/node_modules/npm /usr/local/bin/npm /usr/local/bin/npx

# Run as the unprivileged node user that ships with the image.
USER node

EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
  CMD node -e "fetch('http://127.0.0.1:' + (process.env.PORT || 3000) + '/health').then(r => process.exit(r.ok ? 0 : 1)).catch(() => process.exit(1))"

CMD ["node", "src/index.js"]
