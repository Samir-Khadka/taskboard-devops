# TaskBoard runbook

Day-2 operations for the TaskBoard stack.

## Deploy

**Docker Compose host (EC2 or local):**

```bash
bash scripts/deploy.sh        # pull code, rebuild, restart, health-check
# or by hand:
docker compose pull db prometheus grafana
docker compose up -d --build
```

**From GitHub:** run the **CD** workflow (Actions → CD → Run workflow). It
builds and pushes both images to GHCR, and deploys over SSH when the
repository variable `DEPLOY_ENABLED` is `true`.

**Kubernetes:**

```bash
kubectl apply -k k8s/                                   # raw manifests
helm upgrade --install taskboard helm/taskboard -n taskboard   # or Helm
```

## Rollback

**Compose:** check out the previous commit and redeploy.

```bash
git log --oneline -5
git checkout <previous-sha>
docker compose up -d --build
```

**Kubernetes / Helm:** roll back to the previous release revision, or pin
the image to the previous commit-SHA tag (CD pushes `:latest` and `:<sha>`
for every build).

```bash
helm rollback taskboard -n taskboard
# or: kubectl -n taskboard set image deploy/taskboard-api \
#       api=ghcr.io/samir-khadka/taskboard-devops-api:<previous-sha>
kubectl -n taskboard rollout status deploy/taskboard-api
```

## Logs

```bash
docker compose logs -f api           # compose stack
docker compose logs -f web db
kubectl -n taskboard logs deploy/taskboard-api -f
kubectl -n taskboard get pods,svc,ingress,hpa
```

Metrics sanity checks:

```bash
curl http://localhost:8080/metrics | grep http_requests_total
curl http://localhost:9090/-/healthy          # Prometheus
curl http://localhost:3001/api/health         # Grafana
```

## Common failures

### The API container restarts / the UI says "Could not reach the API"

Usually the database is not ready or the connection string is wrong.

```bash
docker compose ps                    # is db healthy?
docker compose logs db api
docker compose exec db pg_isready
```

Compose starts the API only after the db healthcheck passes, so a crash
loop with `ECONNREFUSED ... 5432` in the API logs points at credentials:
the `POSTGRES_*` values in `.env` must match the ones the db volume was
first initialized with (changing the password in `.env` does **not**
change it inside an existing volume — see Backup/restore below, or
`docker compose down -v` to reinitialize a throwaway stack).

On Kubernetes, the same symptom means the `taskboard-api-secret`
`DATABASE_URL` is wrong or the secret is missing:

```bash
kubectl -n taskboard describe pod -l app=taskboard-api
kubectl -n taskboard get secret taskboard-api-secret
```

### Port already in use (8080 / 3001 / 9090)

Another process owns the host port:

```bash
sudo lsof -i :8080
```

Stop the offender, or override the published port in `.env` /
`docker-compose.yml`.

### Grafana shows "No data"

- Prometheus target down? Open http://localhost:9090/targets — the
  `taskboard-api` target should be UP. If it is down, check the API
  container and that Prometheus can resolve the `api` service name.
- Dashboard appears but panels are empty until the API has served some
  requests — generate traffic from the UI first.

### Terraform: instance is up but the stack is not

Bootstrap output lives in the cloud-init log:

```bash
ssh ubuntu@<public-ip> 'sudo tail -n 100 /var/log/cloud-init-output.log'
```

## Backup & restore (Postgres, compose stack)

```bash
# Backup
docker compose exec -T db pg_dump -U taskboard taskboard > backup-$(date +%F).sql

# Restore (into the running db)
cat backup-2026-10-20.sql | docker compose exec -T db psql -U taskboard taskboard
```

Keep backups somewhere other than the host itself (S3, another machine).
For anything beyond a demo, prefer a managed database (RDS, Cloud SQL,
Neon, ...) with automated snapshots instead of this manual flow.
