# GitOps Guide

This document describes the GitOps setup and patterns used in the DevSecOps Platform Template.

## What is GitOps?

GitOps is a way of implementing Continuous Deployment for cloud-native applications. It works by using Git as a single source of truth for declarative infrastructure and applications.

## GitOps Principles

1. **Declarative** - The entire system is described declaratively
2. **Versioned** - The canonical desired state is versioned in Git
3. **Pulled automatically** - Approved changes are automatically applied
4. **Continuously reconciled** - Agents ensure correctness continuously

## GitOps Options

This platform supports **two GitOps deployment approaches**:

### Option 1: AWS EKS Managed GitOps (Recommended for AWS)

AWS recently announced **EKS Capabilities** which includes fully managed GitOps:

| Component | Description |
|-----------|-------------|
| **Managed Argo CD** | AWS-managed Argo CD as an EKS addon |
| **ACK** | AWS Controllers for Kubernetes - manage AWS resources from K8s |
| **KRO** | Kube Resource Orchestrator - reusable resource bundles |

**Benefits:**

- ✅ AWS handles upgrades and security patches
- ✅ Integrated with EKS console
- ✅ Native AWS IAM authentication via IRSA
- ✅ Reduced operational overhead

**When to use:**

- Running exclusively on AWS EKS
- Want minimal GitOps management overhead
- Need tight AWS service integration

**Setup:** See `infra/terraform/modules/eks-gitops/`

### Option 2: Self-Managed ArgoCD (Recommended for Multi-Cloud)

Traditional self-managed ArgoCD installation:

**Benefits:**

- ✅ Full customization (plugins, SSO, RBAC)
- ✅ Works on any Kubernetes cluster (EKS, GKE, AKS, on-prem)
- ✅ Complete control over upgrades
- ✅ Mature and widely documented

**When to use:**

- Multi-cloud or hybrid deployments
- Need custom ArgoCD plugins
- Want full control over configuration
- Using non-AWS Kubernetes

**Setup:** See `infra/argocd/`

### Comparison Matrix

| Feature | AWS Managed Argo CD | Self-Managed ArgoCD |
|---------|---------------------|---------------------|
| **Upgrades** | AWS handles | You manage |
| **Patching** | Automatic | Manual |
| **Customization** | Limited | Full control |
| **Multi-cloud** | ❌ AWS only | ✅ Any K8s |
| **Cost** | Included in EKS | Free (OSS) |
| **Custom Plugins** | Limited | Fully customizable |
| **SSO Options** | AWS IAM | OIDC/SAML/LDAP/GitHub |
| **Maturity** | New (2024) | Production-proven |

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                      GitOps Architecture                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│   ┌──────────────┐                        ┌──────────────┐      │
│   │   GitHub     │◀───────poll───────────│   ArgoCD     │      │
│   │ Repository   │                        │   Server     │      │
│   └──────┬───────┘                        └──────┬───────┘      │
│          │                                       │               │
│          │ push                                  │ sync          │
│          │                                       │               │
│   ┌──────▼───────┐                        ┌──────▼───────┐      │
│   │  Developer   │                        │  Kubernetes  │      │
│   │              │                        │   Cluster    │      │
│   └──────────────┘                        └──────────────┘      │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

## ArgoCD Setup

Choose one of the following approaches based on your requirements.

### Option A: Self-Managed ArgoCD (Multi-Cloud)

#### Installation

```bash
# Create namespace
kubectl create namespace argocd

# Install ArgoCD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Expose ArgoCD server (for development)
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

#### Initial Configuration

```bash
# Get initial admin password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d

# Login via CLI
argocd login localhost:8080

# Change password
argocd account update-password
```

### Option B: AWS EKS Managed ArgoCD (AWS Only)

#### Prerequisites

- AWS EKS cluster with OIDC provider enabled
- Terraform >= 1.14.0

#### Terraform Setup

```hcl
# In your Terraform configuration
module "eks_gitops" {
  source = "./infra/terraform/modules/eks-gitops"

  cluster_name      = module.eks.cluster_name
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_provider_url = module.eks.oidc_provider_url

  # Enable AWS Managed Argo CD
  enable_managed_argocd = true

  # Optional: Enable AWS Controllers for Kubernetes
  enable_ack = true

  # Optional: Enable Kube Resource Orchestrator
  enable_kro = false

  # GitOps repository configuration
  gitops_repo_url        = "https://github.com/your-org/your-repo.git"
  gitops_target_revision = "main"
  gitops_apps_path       = "infra/argocd/apps"

  tags = var.tags
}
```

#### Deploy

```bash
cd infra/terraform/environments/dev
terraform init
terraform plan
terraform apply
```

#### Access ArgoCD

With AWS Managed ArgoCD, access is integrated with the AWS EKS console:

1. Navigate to **Amazon EKS** in AWS Console
2. Select your cluster
3. Go to **Add-ons** tab
4. Click on **Argo CD** to access the dashboard

Or via kubectl:

```bash
# Get the ArgoCD server URL
kubectl get svc -n argocd argocd-server -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'

# For IRSA-based authentication, use AWS credentials
aws eks get-token --cluster-name your-cluster | argocd login ...
```

## App of Apps Pattern

The platform uses the "App of Apps" pattern where a root application manages all other applications.

### Root Application

```yaml
# infra/argocd/root-app.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: devsecops-platform
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/abhishekpanda0620/devsecops-platform-template.git
    path: infra/argocd/apps
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

### Child Applications

```
infra/argocd/apps/
├── user-service-dev.yaml     # Dev environment
├── user-service-prod.yaml    # Production environment
├── monitoring.yaml           # Prometheus/Grafana stack
```

## Repository Structure

### Manifest Organization

```
infra/
├── k8s/
│   ├── base/                 # Base manifests
│   │   ├── deployment.yaml
│   │   ├── service.yaml
│   │   ├── hpa.yaml
│   │   └── kustomization.yaml
│   └── overlays/
│       ├── dev/              # Dev overlay
│       │   ├── kustomization.yaml
│       │   └── namespace.yaml
│       ├── staging/          # Staging overlay
│       └── prod/             # Production overlay
│           ├── kustomization.yaml
│           ├── namespace.yaml
│           └── ingress.yaml
└── argocd/
    ├── root-app.yaml
    └── apps/
```

### Kustomize Overlays

**Base** (`infra/k8s/base/kustomization.yaml`):

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - deployment.yaml
  - service.yaml
  - hpa.yaml
```

**Dev Overlay** (`infra/k8s/overlays/dev/kustomization.yaml`):

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: dev
resources:
  - ../../base
images:
  - name: user-service
    newTag: latest
replicas:
  - name: user-service
    count: 1
```

**Prod Overlay** (`infra/k8s/overlays/prod/kustomization.yaml`):

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: prod
resources:
  - ../../base
  - ingress.yaml
images:
  - name: user-service
    newTag: v1.0.0
replicas:
  - name: user-service
    count: 3
```

## Sync Policies

### Dev Environment (Automatic)

```yaml
syncPolicy:
  automated:
    prune: true      # Remove deleted resources
    selfHeal: true   # Correct drift automatically
```

### Production Environment (Manual)

```yaml
syncPolicy:
  # No automated sync - manual approval required
  syncOptions:
    - CreateNamespace=true
```

## Promotion Workflow

### 1. Code Change

Developer pushes code to `main` branch.

### 2. CI Pipeline

- Builds and tests
- Scans for security issues
- Builds and pushes Docker image
- Signs image

### 3. Manifest Update (Dev)

CD pipeline updates dev overlay:

```bash
cd infra/k8s/overlays/dev
kustomize edit set image user-service=ghcr.io/user/app:sha-abc123
```

![CD Pipeline Graph](../screenshots/cd-pipeline-graph.png)

### 4. ArgoCD Sync (Dev)

ArgoCD detects change and syncs to dev cluster.

### 5. Smoke Tests

Automated tests verify deployment.

### 6. Promotion to Staging

```bash
cd infra/k8s/overlays/staging
kustomize edit set image user-service=ghcr.io/user/app:sha-abc123
git commit -m "Promote sha-abc123 to staging"
git push
```

### 7. Promotion to Production

1. Create PR for production manifest change
2. Require review and approval
3. Merge triggers ArgoCD sync

## Health Checks

ArgoCD monitors application health:

```yaml
# Custom health check
health:
  customization:
    lua: |
      hs = {}
      if obj.status ~= nil then
        if obj.status.health ~= nil then
          hs.status = obj.status.health.status
          hs.message = obj.status.health.message
        end
      end
      return hs
```

## Rollback

### Automatic (on health check failure)

```yaml
syncPolicy:
  automated:
    selfHeal: true
```

### Manual

```bash
# Via CLI
argocd app rollback user-service-prod

# Via UI
# Navigate to app → History → Rollback
```

### History

ArgoCD maintains revision history:

```bash
argocd app history user-service-prod
```

## Notifications

### Slack Integration

```yaml
# In argocd-notifications-cm ConfigMap
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-notifications-cm
data:
  service.slack: |
    token: $slack-token
  template.app-sync-succeeded: |
    message: |
      Application {{.app.metadata.name}} sync succeeded!
  trigger.on-sync-succeeded: |
    - when: app.status.operationState.phase in ['Succeeded']
      send: [app-sync-succeeded]
```

### Application Annotations

```yaml
annotations:
  notifications.argoproj.io/subscribe.on-sync-succeeded.slack: deployments
  notifications.argoproj.io/subscribe.on-sync-failed.slack: deployments-alerts
```

![Slack Notifications](../screenshots/slack-deployment-alerts.png)

## Best Practices

### 1. Separate Repositories

Consider separating:

- Application code repository
- GitOps manifests repository

### 2. Use Helm or Kustomize

Avoid raw manifests. Use:

- Kustomize for overlays
- Helm for reusable charts

### 3. Protect Main Branch

- Require PR reviews
- Run CI checks before merge
- Use signed commits

### 4. Environment Isolation

- Use separate namespaces
- Apply network policies
- Different RBAC per environment

### 5. Secrets Management

Don't store secrets in Git. Use:

- Sealed Secrets
- External Secrets Operator
- SOPS

### 6. Monitor Sync Status

```bash
# Check all apps
argocd app list

# Check specific app
argocd app get user-service-prod
```

![ArgoCD Applications List](../screenshots/argocd-applications-list.png)

## Troubleshooting

### Sync Issues

```bash
# Check application status
argocd app get <app-name>

# View sync details
argocd app sync <app-name> --dry-run

# Force refresh
argocd app refresh <app-name>
```

### Manifest Issues

```bash
# Validate locally
kubectl apply --dry-run=client -k infra/k8s/overlays/dev

# Check kustomize output
kustomize build infra/k8s/overlays/dev
```

### Resource Drift

```bash
# Check diff
argocd app diff <app-name>

# Sync to correct drift
argocd app sync <app-name>
```

## References

### Self-Managed ArgoCD

- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [GitOps Principles](https://opengitops.dev/)
- [Kustomize](https://kustomize.io/)

### AWS EKS Managed GitOps

- [AWS EKS Capabilities](https://docs.aws.amazon.com/eks/latest/userguide/eks-add-ons.html)
- [AWS Controllers for Kubernetes (ACK)](https://aws-controllers-k8s.github.io/community/)
- [Kube Resource Orchestrator (KRO)](https://github.com/awslabs/kro)
- [EKS IRSA (IAM Roles for Service Accounts)](https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html)

## Infrastructure Teardown

### Removing ArgoCD

When destroying the infrastructure via Terraform (`terraform destroy`), you might see a warning that some resources were kept:

```text
Warning: Helm uninstall returned an information message
These resources were kept due to the resource policy:
[CustomResourceDefinition] applications.argoproj.io
...
```

This is a **safety feature** of the ArgoCD Helm chart. The CRDs are annotated with `"helm.sh/resource-policy": "keep"` to prevent accidental deletion of all GitOps applications and their history.

If you are performing a complete teardown and want to remove these CRDs, you must delete them manually:

```bash
kubectl delete crd applications.argoproj.io applicationsets.argoproj.io appprojects.argoproj.io
```

### Removing Cloud Resources (ALBs)

If you use `terraform destroy` without deleting Kubernetes resources first, cloud resources created by controllers (like ALBs from Ingress) may be orphaned.

**Always delete application resources/ingress before destroying the cluster:**

```bash
kubectl delete -k infra/k8s/overlays/dev
```

### Emptying ECR Repositories

Terraform may fail to destroy ECR repositories if they contain images (unless `force_delete` is enabled). Best practice is to empty them first:

```bash
# Delete all images in a repository
aws ecr batch-delete-image \
    --repository-name devsecops/user-service \
    --image-ids "$(aws ecr list-images --repository-name devsecops/user-service --query 'imageIds[*]' --output json)" || true
```
