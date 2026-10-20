# TaskBoard — a DevOps portfolio project

[![CI](https://github.com/Samir-Khadka/taskboard-devops/actions/workflows/ci.yml/badge.svg)](https://github.com/Samir-Khadka/taskboard-devops/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

**A small task-board app wrapped in a complete, production-shaped delivery system** — Docker, CI/CD, infrastructure as code, Kubernetes, Helm, monitoring and configuration management, all in one repository.

The application itself is intentionally tiny (a Node.js/Express task API + a
static UI). The point of the project is everything around it: how the code is
tested, packaged, deployed, observed and operated. Design notes live in
[docs/architecture.md](docs/architecture.md); day-2 operations in
[docs/runbook.md](docs/runbook.md).

## What this demonstrates

| Area                  | Where                                          | Highlights                                                                 |
| --------------------- | ---------------------------------------------- | -------------------------------------------------------------------------- |
| **Docker**            | `app/Dockerfile`, `web/Dockerfile`             | Multi-stage builds, non-root user, HEALTHCHECKs, slim Alpine runtimes      |
| **Compose**           | `docker-compose.yml`                           | 5 services, healthcheck-gated startup order, named volumes, `.env` config  |
| **CI**                | `.github/workflows/ci.yml`                     | Test + lint, Docker builds with layer caching, `terraform fmt/validate`, `helm lint`, kubeconform |
| **CD**                | `.github/workflows/cd.yml`                     | Manual dispatch → build & push to GHCR → opt-in SSH deploy                 |
| **Kubernetes**        | `k8s/`                                         | Namespace, ConfigMap/Secret split, probes, resources, Ingress, HPA, kustomize |
| **Helm**              | `helm/taskboard/`                              | Parameterized chart (API + optional web), existingSecret support          |
| **Monitoring**        | `monitoring/`                                  | Prometheus scraping, provisioned Grafana datasource + dashboard (rate, latency, errors, memory) |
| **IaC**               | `terraform/`                                   | AWS VPC, subnet, IGW, security group, EC2 bootstrap, Elastic IP            |
| **Config management** | `ansible/`                                     | Idempotent playbook: Docker from the official repo, ufw, checkout, stack up |
| **App engineering**   | `app/`                                         | Zero-framework tests (`node:test`), Prometheus metrics, graceful SIGTERM shutdown, in-memory/Postgres store switch |

## Architecture

```mermaid
flowchart LR
    user([Browser / API client])
    subgraph host["Single host (compose) or cluster (Kubernetes)"]
        ingress["nginx<br/>(web container or ingress-nginx)"]
        web["web<br/>static UI"]
        api["api<br/>Node.js / Express"]
        db[("PostgreSQL 16")]
        prom["Prometheus"]
        graf["Grafana"]
    end
    user -->|HTTP| ingress
    ingress -->|/| web
    ingress -->|/api, /metrics| api
    api -->|SQL, DATABASE_URL| db
    prom -->|scrape /metrics| api
    graf -->|query| prom
```

More detail, the request flow and scaling notes:
[docs/architecture.md](docs/architecture.md).

## Quickstart

You only need Docker with the Compose plugin:

```bash
git clone https://github.com/Samir-Khadka/taskboard-devops.git
cd taskboard-devops
cp .env.example .env        # optional — defaults work out of the box
docker compose up -d --build
```

| Service    | URL                     | Notes                                   |
| ---------- | ----------------------- | --------------------------------------- |
| Web UI     | http://localhost:8080   | Add / toggle / delete tasks             |
| API        | http://localhost:8080/api/tasks | Proxied by nginx (api itself is internal) |
| Metrics    | http://localhost:8080/metrics   | Prometheus exposition format    |
| Prometheus | http://localhost:9090   | Target `taskboard-api`                  |
| Grafana    | http://localhost:3001   | `admin` / `admin` (from `.env`), dashboard "TaskBoard API" |

Run the API without any infrastructure (in-memory store, for development):

```bash
cd app && npm ci && npm test && npm start   # http://localhost:3000
```

## Repository layout

```
.
├── app/                  # Node.js API (src, tests, Dockerfile, package-lock)
├── web/                  # Static UI + nginx (Dockerfile, default.conf.template)
├── docker-compose.yml    # Full local / single-host stack
├── monitoring/           # Prometheus config, Grafana provisioning + dashboard
├── k8s/                  # Raw Kubernetes manifests (+ kustomization.yaml)
├── helm/taskboard/       # Helm chart for the same workloads
├── terraform/            # AWS network + EC2 host
├── ansible/              # Host configuration playbook
├── scripts/deploy.sh     # On-server deploy (used by CD over SSH)
├── docs/                 # architecture.md, runbook.md
├── .github/workflows/    # ci.yml (every push/PR), cd.yml (manual dispatch)
└── Makefile              # up / down / test / k8s-apply / tf-plan ...
```

## CI / CD

**CI** (`.github/workflows/ci.yml`) runs on every push and PR to `main`,
in four parallel jobs:

1. **app-test** — `npm ci`, syntax lint, `node --test` suite.
2. **docker-build** — builds both images (Buildx, GitHub layer cache),
   without pushing.
3. **terraform** — `terraform fmt -check`, `init -backend=false`,
   `validate`.
4. **k8s-helm** — `helm lint`, `helm template`, and kubeconform in strict
   mode over the raw manifests.

**CD** (`.github/workflows/cd.yml`) is manual (`workflow_dispatch`): it
builds and pushes both images to GHCR tagged `latest` and the commit SHA,
then — only if enabled — SSHes to the server and runs
`scripts/deploy.sh`. To enable deploys, set:

| Kind     | Name             | Value                                             |
| -------- | ---------------- | ------------------------------------------------- |
| Variable | `DEPLOY_ENABLED` | `true`                                            |
| Secret   | `DEPLOY_HOST`    | Server hostname or IP                             |
| Secret   | `DEPLOY_USER`    | SSH user (e.g. `ubuntu`)                          |
| Secret   | `DEPLOY_SSH_KEY` | Private key for that user                         |

The server expects a checkout of this repo at `~/taskboard-devops`.

## Kubernetes

Raw manifests (create the database secret first — it is intentionally not
in the kustomization):

```bash
kubectl create namespace taskboard
kubectl -n taskboard create secret generic taskboard-api-secret \
  --from-literal=DATABASE_URL='postgres://user:pass@your-postgres:5432/taskboard'
kubectl apply -k k8s/
```

Or the Helm chart, which takes the secret by name instead of owning it:

```bash
helm install taskboard helm/taskboard -n taskboard --create-namespace \
  --set api.existingSecret=taskboard-api-secret \
  --set ingress.host=taskboard.example.com
```

Both ship: 2 API replicas with CPU/memory requests & limits, liveness and
readiness probes on `/health`, an nginx Ingress routing `/` → web and
`/api` + `/metrics` → api, and an HPA (2–6 replicas at 70% CPU). With raw
manifests the ingress does the routing that the nginx template does under compose;
with Helm the web tier can be disabled (`--set web.enabled=false`).

## Terraform

Provisions the single-host environment on AWS: VPC, public subnet,
internet gateway + route table, a security group (SSH and the
Grafana/Prometheus ports restricted to an admin CIDR; 80/443/8080 public),
and an Ubuntu 22.04 EC2 instance whose `user_data` installs Docker, clones
this repo and starts the compose stack. An Elastic IP keeps the address
stable.

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars   # set admin_cidr to your IP!
terraform init && terraform plan && terraform apply
terraform output app_url
```

Local state is the default; a commented S3 backend block in
`terraform/versions.tf` shows the production-style setup.

## Ansible

The same host, configured idempotently (safe to re-run; also the way to
apply changes to a host that already exists):

```bash
cd ansible
cp inventory.example inventory   # point at your host
ansible-playbook -i inventory playbook.yml
```

It installs Docker from the official apt repository, enables ufw
(22/80/443/8080), checks out the repo and brings the compose stack up.

## Design decisions & trade-offs

- **One app, three runtimes.** Compose for a single host, raw manifests to
  show the primitives, Helm for parameterization. Keeping all three honest
  is the point — the health endpoint, probes and image contract are shared.
- **The API hides its storage.** Tests run with zero infrastructure
  (in-memory store on an ephemeral port), the same binary runs against
  Postgres in real deployments — chosen by the presence of `DATABASE_URL`.
- **Metrics are a first-class endpoint**, not an afterthought: a labeled
  request counter + latency histogram, default Node.js metrics, and a
  Grafana dashboard provisioned from code.
- **Secrets stay out of git.** Compose uses `.env`, Kubernetes takes an
  externally created Secret, Terraform's admin CIDR forces you to think
  about who can reach the admin surfaces. `secret.example.yaml` is a
  placeholder and is excluded from the kustomization.
- **Deliberately not here:** TLS (bring your own ingress/ALB + cert
  manager), managed database backups, multi-AZ anything. The runbook calls
  these out instead of pretending a demo stack is a production platform.

## Future improvements

- Trivy image scanning + SBOM in CI; pin images by digest.
- Preview environments per pull request.
- Alert rules (error-ratio burn) and a SLO dashboard next to the API one.
- Terraform modules + remote state as the default; an ALB + ACM front door.
- Argo CD / Flux GitOps instead of SSH deploys.

## License

MIT — see [LICENSE](LICENSE). © 2026 Samir Khadka.
