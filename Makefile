.PHONY: up down logs ps build test clean k8s-apply k8s-delete helm-lint helm-template tf-init tf-plan

# ---- Docker Compose ---------------------------------------------------------

up:            ## Build and start the whole stack
	docker compose up -d --build

down:          ## Stop the stack (data volumes are kept)
	docker compose down

logs:          ## Tail logs from all services
	docker compose logs -f

ps:            ## Show service status
	docker compose ps

build:         ## Build both app images
	docker compose build

test:          ## Run the API test suite locally (no Docker needed)
	cd app && npm ci && npm run lint && npm test

clean:         ## Stop the stack and delete its data volumes
	docker compose down -v

# ---- Kubernetes ---------------------------------------------------------------

k8s-apply:     ## Apply the raw manifests (create the DB secret first — see k8s/kustomization.yaml)
	kubectl apply -k k8s/

k8s-delete:    ## Remove everything the raw manifests created
	kubectl delete -k k8s/

helm-lint:     ## Lint the Helm chart
	helm lint helm/taskboard

helm-template: ## Render the Helm chart to stdout
	helm template taskboard helm/taskboard

# ---- Terraform ------------------------------------------------------------------

tf-init:       ## terraform init (local backend by default)
	cd terraform && terraform init

tf-plan:       ## terraform plan
	cd terraform && terraform plan
