# Setup Guide

This guide walks you through setting up the DevSecOps Platform Template for your organization.

## Prerequisites

### Required Tools

| Tool | Version | Purpose |
|------|---------|---------|
| Docker | 24+ | Container runtime |
| Docker Compose | 2.0+ | Local development |
| Node.js | 20+ | Application runtime |
| kubectl | 1.28+ | Kubernetes CLI |
| Helm | 3.12+ | Kubernetes package manager |
| Terraform | 1.5+ | Infrastructure as Code |
| AWS CLI | 2.0+ | AWS operations |
| ArgoCD CLI | 2.8+ | GitOps operations |
| Cosign | 2.0+ | Image signing |

### Install Prerequisites

```bash
# macOS with Homebrew
brew install docker docker-compose node kubectl helm terraform awscli argocd cosign

# Ubuntu/Debian
curl -fsSL https://get.docker.com | sh
sudo apt install nodejs npm
# For other tools, follow official installation guides
```

## Quick Start

### 1. Clone the Repository

```bash
git clone https://github.com/abhishekpanda0620/devsecops-platform-template.git
cd devsecops-platform-template
```

### 2. Initialize Local Environment

```bash
# Install dependencies and set up pre-commit hooks
make init

# Copy environment file
cp .env.example .env
```

### 3. Start Local Development

```bash
# Start the application locally
make dev

# Or start with Docker
make dev-docker

# Access the application
curl http://localhost:3000/health
```

### 4. Run Security Scans

```bash
# Run all security scans
make security-scan

# Or run individual scans
make scan-secrets    # Gitleaks
make scan-sast       # Semgrep
make scan-deps       # Trivy
make scan-eol        # End-of-life check
make scan-iac        # Checkov
```

## Cloud Infrastructure Setup

### AWS Configuration

1. **Configure AWS Credentials**

```bash
# Configure AWS CLI
aws configure

# Or use environment variables
export AWS_ACCESS_KEY_ID=your-access-key
export AWS_SECRET_ACCESS_KEY=your-secret-key
export AWS_DEFAULT_REGION=us-east-1
```

2. **Create Terraform Backend**

```bash
# Create S3 bucket for state
aws s3 mb s3://your-terraform-state-bucket --region us-east-1

# Create DynamoDB table for locking
aws dynamodb create-table \
  --table-name terraform-state-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5
```

3. **Update Backend Configuration**

Edit `infra/terraform/environments/dev/main.tf`:

```hcl
backend "s3" {
  bucket         = "your-terraform-state-bucket"
  key            = "devsecops/dev/terraform.tfstate"
  region         = "us-east-1"
  encrypt        = true
  dynamodb_table = "terraform-state-lock"
}
```

4. **Deploy Infrastructure**

```bash
# Initialize and plan
make infra-init ENVIRONMENT=dev
make infra-plan ENVIRONMENT=dev

# Apply (requires approval)
make infra-apply ENVIRONMENT=dev
```

5. **Configure kubectl**

```bash
# Update kubeconfig
aws eks update-kubeconfig --name devsecops-dev --region us-east-1

# Verify connection
kubectl get nodes
```

## GitOps Setup

### 1. Install ArgoCD

```bash
# Create namespace
kubectl create namespace argocd

# Install ArgoCD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Get admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

### 2. Configure ArgoCD

```bash
# Port forward ArgoCD UI
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Login via CLI
argocd login localhost:8080 --username admin --password <password>

# Add repository
argocd repo add https://github.com/abhishekpanda0620/devsecops-platform-template.git
```

### 3. Deploy Applications

```bash
# Deploy root application (App of Apps)
make deploy-argocd

# Or apply directly
kubectl apply -f infra/argocd/root-app.yaml
```

## GitHub Actions Setup

### 1. Configure Secrets

Add the following secrets to your GitHub repository:

| Secret | Description |
|--------|-------------|
| `GHCR_TOKEN` | GitHub Container Registry token |
| `AWS_ROLE_ARN` | AWS IAM role for OIDC |
| `GITLEAKS_LICENSE` | Gitleaks Enterprise license (optional) |
| `SNYK_TOKEN` | Snyk API token (optional) |

### 2. Enable GitHub Features

1. Go to Repository Settings → Security → Code security and analysis
2. Enable:
   - Dependency graph
   - Dependabot alerts
   - Dependabot security updates
   - Code scanning
   - Secret scanning

### 3. Configure Environments

1. Go to Repository Settings → Environments
2. Create environments: `dev`, `staging`, `prod`
3. For `prod`, add required reviewers

## Runtime Security Setup

### 1. Deploy Gatekeeper

```bash
# Install OPA Gatekeeper
kubectl apply -f https://raw.githubusercontent.com/open-policy-agent/gatekeeper/master/deploy/gatekeeper.yaml

# Apply constraint templates
kubectl apply -f runtime/opa-gatekeeper/templates/

# Apply constraints
kubectl apply -f runtime/opa-gatekeeper/constraints/
```

### 2. Deploy Falco

Falco is deployed via ArgoCD, but you can also install manually:

```bash
helm repo add falcosecurity https://falcosecurity.github.io/charts
helm repo update

helm install falco falcosecurity/falco \
  --namespace falco-system \
  --create-namespace \
  --set driver.kind=ebpf
```

## Monitoring Setup

The monitoring stack (Prometheus, Grafana, Loki) is deployed via ArgoCD. Access Grafana:

```bash
# Port forward Grafana
kubectl port-forward svc/monitoring-grafana -n monitoring 3000:80

# Get admin password
kubectl get secret monitoring-grafana -n monitoring -o jsonpath="{.data.admin-password}" | base64 -d
```

## Verification

### Health Checks

```bash
# Check application health
curl http://localhost:3000/health

# Check Kubernetes pods
kubectl get pods -A

# Check ArgoCD applications
argocd app list
```

### Run End-to-End Test

```bash
# Run all tests
make test

# Run security scan
make security-scan

# Check EOL status
make scan-eol
```

## Troubleshooting

### Common Issues

1. **Docker build fails**
   - Ensure Docker daemon is running
   - Check available disk space

2. **Terraform init fails**
   - Verify AWS credentials
   - Check S3 bucket permissions

3. **ArgoCD sync fails**
   - Check repository access
   - Verify manifest syntax: `kubectl apply --dry-run=client -k infra/k8s/overlays/dev`

4. **Gatekeeper blocks deployments**
   - Check constraint violations: `kubectl get constraints`
   - Review constraint parameters

### Getting Help

- Open an issue on GitHub
- Check the [ROADMAP.md](ROADMAP.md) for planned features
- Review [architecture.md](architecture.md) for system design

## Next Steps

1. Customize the sample application
2. Add your own Semgrep rules
3. Configure alerting in Alertmanager
4. Set up Slack notifications for ArgoCD
5. Implement additional Gatekeeper policies
