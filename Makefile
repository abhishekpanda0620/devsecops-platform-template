# DevSecOps Platform Template - Makefile
# Automation commands for development, testing, and deployment

.PHONY: help init dev build test lint security-scan docker-build docker-push deploy-argocd infra-plan infra-apply clean

# Default target
.DEFAULT_GOAL := help

# Variables
APP_NAME := user-service
REGISTRY := ghcr.io/abhishekpanda0620/devsecops-platform-template
IMAGE_TAG := $(shell git rev-parse --short HEAD 2>/dev/null || echo "latest")
ENVIRONMENT ?= dev

# Colors for terminal output
BLUE := \033[34m
GREEN := \033[32m
YELLOW := \033[33m
RED := \033[31m
RESET := \033[0m

##@ General

help: ## Display this help
	@awk 'BEGIN {FS = ":.*##"; printf "\n$(BLUE)DevSecOps Platform Template$(RESET)\n\nUsage:\n  make $(GREEN)<target>$(RESET)\n"} /^[a-zA-Z_0-9-]+:.*?##/ { printf "  $(GREEN)%-20s$(RESET) %s\n", $$1, $$2 } /^##@/ { printf "\n$(YELLOW)%s$(RESET)\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

##@ Development

init: ## Initialize the development environment
	@echo "$(BLUE)Initializing development environment...$(RESET)"
	@cd app && npm install
	@cp -n .env.example .env 2>/dev/null || true
	@echo "$(GREEN)✓ Development environment initialized$(RESET)"

dev: ## Start local development server
	@echo "$(BLUE)Starting development server...$(RESET)"
	@cd app && npm run dev

dev-docker: ## Start development environment with Docker
	@echo "$(BLUE)Starting  cvzDocker development environment...$(RESET)"
	@docker-compose --profile dev up -d user-service-dev
	@echo "$(GREEN)✓ Development server running at http://localhost:3001$(RESET)"

##@ Testing

test: ## Run unit tests
	@echo "$(BLUE)Running unit tests...$(RESET)"
	@cd app && npm test

test-coverage: ## Run tests with coverage report
	@echo "$(BLUE)Running tests with coverage...$(RESET)"
	@cd app && npm test -- --coverage

lint: ## Run linter
	@echo "$(BLUE)Running linter...$(RESET)"
	@cd app && npm run lint

##@ Security

security-scan: ## Run all security scans locally
	@echo "$(BLUE)Running security scans...$(RESET)"
	@$(MAKE) scan-secrets
	@$(MAKE) scan-sast
	@$(MAKE) scan-deps
	@$(MAKE) scan-eol
	@echo "$(GREEN)✓ All security scans completed$(RESET)"

scan-secrets: ## Scan for secrets with Gitleaks
	@echo "$(BLUE)Scanning for secrets...$(RESET)"
	@docker run --rm -v $(PWD):/path zricethezav/gitleaks:latest detect --source=/path || true

scan-sast: ## Run SAST scan with Semgrep
	@echo "$(BLUE)Running SAST scan...$(RESET)"
	@docker run --rm -v $(PWD):/src semgrep/semgrep semgrep scan --config=auto /src || true

scan-deps: ## Scan dependencies with Trivy
	@echo "$(BLUE)Scanning dependencies...$(RESET)"
	@docker run --rm -v $(PWD):/project aquasec/trivy:latest fs /project --severity HIGH,CRITICAL || true

scan-iac: ## Scan IaC with Checkov
	@echo "$(BLUE)Scanning Infrastructure as Code...$(RESET)"
	@docker run --rm -v $(PWD):/tf bridgecrew/checkov:latest -d /tf/infra --framework terraform,kubernetes,helm || true

scan-eol: ## Check for end-of-life technologies
	@echo "$(BLUE)Checking for EOL technologies...$(RESET)"
	@npx eol-check || true

scan-container: docker-build ## Scan container image with Trivy
	@echo "$(BLUE)Scanning container image...$(RESET)"
	@docker run --rm -v /var/run/docker.sock:/var/run/docker.sock aquasec/trivy:latest image $(REGISTRY)/$(APP_NAME):$(IMAGE_TAG)

##@ Build

build: ## Build the application
	@echo "$(BLUE)Building application...$(RESET)"
	@cd app && npm run build 2>/dev/null || echo "No build step required"
	@echo "$(GREEN)✓ Build completed$(RESET)"

docker-build: ## Build Docker image
	@echo "$(BLUE)Building Docker image: $(REGISTRY)/$(APP_NAME):$(IMAGE_TAG)$(RESET)"
	@docker build -t $(REGISTRY)/$(APP_NAME):$(IMAGE_TAG) -t $(REGISTRY)/$(APP_NAME):latest ./app
	@echo "$(GREEN)✓ Docker image built$(RESET)"

docker-push: docker-build ## Push Docker image to registry
	@echo "$(BLUE)Pushing Docker image...$(RESET)"
	@docker push $(REGISTRY)/$(APP_NAME):$(IMAGE_TAG)
	@docker push $(REGISTRY)/$(APP_NAME):latest
	@echo "$(GREEN)✓ Docker image pushed$(RESET)"

sbom: docker-build ## Generate SBOM for the container
	@echo "$(BLUE)Generating SBOM...$(RESET)"
	@mkdir -p sbom
	@docker run --rm -v /var/run/docker.sock:/var/run/docker.sock -v $(PWD)/sbom:/sbom anchore/syft $(REGISTRY)/$(APP_NAME):$(IMAGE_TAG) -o spdx-json=/sbom/$(APP_NAME)-sbom.spdx.json
	@echo "$(GREEN)✓ SBOM generated in sbom/$(RESET)"

sign-image: docker-push ## Sign Docker image with Cosign
	@echo "$(BLUE)Signing Docker image...$(RESET)"
	@cosign sign --yes $(REGISTRY)/$(APP_NAME):$(IMAGE_TAG)
	@echo "$(GREEN)✓ Image signed$(RESET)"

##@ Infrastructure

infra-init: ## Initialize Terraform
	@echo "$(BLUE)Initializing Terraform...$(RESET)"
	@cd infra/terraform/environments/$(ENVIRONMENT) && terraform init

infra-plan: infra-init ## Plan Terraform changes
	@echo "$(BLUE)Planning Terraform changes for $(ENVIRONMENT)...$(RESET)"
	@cd infra/terraform/environments/$(ENVIRONMENT) && terraform plan

infra-apply: ## Apply Terraform changes (requires approval)
	@echo "$(YELLOW)Applying Terraform changes for $(ENVIRONMENT)...$(RESET)"
	@cd infra/terraform/environments/$(ENVIRONMENT) && terraform apply

infra-destroy: ## Destroy Terraform infrastructure (dangerous!)
	@echo "$(RED)Destroying Terraform infrastructure for $(ENVIRONMENT)...$(RESET)"
	@cd infra/terraform/environments/$(ENVIRONMENT) && terraform destroy

##@ Kubernetes

k8s-dev: ## Deploy to dev environment
	@echo "$(BLUE)Deploying to dev environment...$(RESET)"
	@kubectl apply -k infra/k8s/overlays/dev

k8s-prod: ## Deploy to prod environment
	@echo "$(BLUE)Deploying to prod environment...$(RESET)"
	@kubectl apply -k infra/k8s/overlays/prod

k8s-diff: ## Show diff for Kubernetes manifests
	@echo "$(BLUE)Showing Kubernetes diff for $(ENVIRONMENT)...$(RESET)"
	@kubectl diff -k infra/k8s/overlays/$(ENVIRONMENT) || true

##@ GitOps

deploy-argocd: ## Deploy ArgoCD applications
	@echo "$(BLUE)Deploying ArgoCD applications...$(RESET)"
	@kubectl apply -f infra/argocd/root-app.yaml

argocd-sync: ## Sync ArgoCD applications
	@echo "$(BLUE)Syncing ArgoCD applications...$(RESET)"
	@argocd app sync devsecops-platform --prune

##@ Utilities

clean: ## Clean up build artifacts
	@echo "$(BLUE)Cleaning up...$(RESET)"
	@rm -rf app/node_modules
	@rm -rf app/coverage
	@rm -rf sbom/*.json
	@docker-compose down --volumes --remove-orphans 2>/dev/null || true
	@echo "$(GREEN)✓ Cleanup completed$(RESET)"

logs: ## Show application logs
	@docker-compose logs -f user-service

shell: ## Open shell in running container
	@docker-compose exec user-service sh

status: ## Show status of services
	@echo "$(BLUE)Docker Compose Status:$(RESET)"
	@docker-compose ps
	@echo ""
	@echo "$(BLUE)Kubernetes Status ($(ENVIRONMENT)):$(RESET)"
	@kubectl get pods -n $(ENVIRONMENT) 2>/dev/null || echo "Not connected to Kubernetes"

version: ## Show version information
	@echo "$(BLUE)Version Information:$(RESET)"
	@echo "  App: $(shell cat app/package.json | jq -r .version 2>/dev/null || echo 'unknown')"
	@echo "  Image Tag: $(IMAGE_TAG)"
	@echo "  Environment: $(ENVIRONMENT)"

##@ Pre-commit Hooks

pre-commit-install: ## Install pre-commit hooks
	@echo "$(BLUE)Installing pre-commit hooks...$(RESET)"
	@pip install pre-commit || pip3 install pre-commit
	@pre-commit install
	@pre-commit install --hook-type commit-msg
	@echo "$(GREEN)✓ Pre-commit hooks installed$(RESET)"

pre-commit-run: ## Run pre-commit on all files
	@echo "$(BLUE)Running pre-commit checks...$(RESET)"
	@pre-commit run --all-files

pre-commit-update: ## Update pre-commit hooks to latest versions
	@echo "$(BLUE)Updating pre-commit hooks...$(RESET)"
	@pre-commit autoupdate
	@echo "$(GREEN)✓ Pre-commit hooks updated$(RESET)"

##@ Observability

observability-deps: ## Add Helm repos for observability stack
	@echo "$(BLUE)Adding Helm repositories...$(RESET)"
	@helm repo add prometheus-community https://prometheus-community.github.io/helm-charts || true
	@helm repo add grafana https://grafana.github.io/helm-charts || true
	@helm repo update
	@echo "$(GREEN)✓ Helm repositories added$(RESET)"

observability-install: observability-deps ## Install observability stack via Helm (non-GitOps)
	@echo "$(BLUE)Installing observability stack...$(RESET)"
	@kubectl create namespace observability --dry-run=client -o yaml | kubectl apply -f -
	@helm upgrade --install prometheus prometheus-community/kube-prometheus-stack \
		--namespace observability \
		--values infra/helm/charts/observability/values.yaml \
		--wait
	@helm upgrade --install loki grafana/loki-stack \
		--namespace observability \
		--set loki.persistence.enabled=true \
		--set promtail.enabled=true \
		--set grafana.enabled=false \
		--wait
	@echo "$(GREEN)✓ Observability stack installed$(RESET)"

observability-argocd: ## Deploy observability stack via ArgoCD (GitOps)
	@echo "$(BLUE)Deploying observability stack via ArgoCD...$(RESET)"
	@kubectl apply -f infra/argocd/apps/observability.yaml
	@echo "$(GREEN)✓ Observability ArgoCD application created$(RESET)"
	@echo "$(YELLOW)Run 'argocd app sync observability-stack' to sync$(RESET)"

observability-status: ## Show observability stack status
	@echo "$(BLUE)Observability Stack Status:$(RESET)"
	@echo ""
	@echo "$(YELLOW)Pods:$(RESET)"
	@kubectl get pods -n observability 2>/dev/null || echo "Namespace not found"
	@echo ""
	@echo "$(YELLOW)Services:$(RESET)"
	@kubectl get svc -n observability 2>/dev/null || echo "Namespace not found"

observability-portforward: ## Port-forward Grafana (localhost:3000)
	@echo "$(BLUE)Port-forwarding Grafana to localhost:3000...$(RESET)"
	@echo "$(YELLOW)Default credentials: admin / prom-operator$(RESET)"
	@kubectl port-forward -n observability svc/prometheus-grafana 3000:80

observability-uninstall: ## Uninstall observability stack
	@echo "$(RED)Uninstalling observability stack...$(RESET)"
	@helm uninstall prometheus -n observability 2>/dev/null || true
	@helm uninstall loki -n observability 2>/dev/null || true
	@kubectl delete namespace observability --ignore-not-found
	@echo "$(GREEN)✓ Observability stack uninstalled$(RESET)"
