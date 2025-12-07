# GitOps Guide

This document describes the GitOps setup and patterns used in the DevSecOps Platform Template.

## What is GitOps?

GitOps is a way of implementing Continuous Deployment for cloud-native applications. It works by using Git as a single source of truth for declarative infrastructure and applications.

## GitOps Principles

1. **Declarative** - The entire system is described declaratively
2. **Versioned** - The canonical desired state is versioned in Git
3. **Pulled automatically** - Approved changes are automatically applied
4. **Continuously reconciled** - Agents ensure correctness continuously

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

### Installation

```bash
# Create namespace
kubectl create namespace argocd

# Install ArgoCD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Expose ArgoCD server (for development)
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

### Initial Configuration

```bash
# Get initial admin password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d

# Login via CLI
argocd login localhost:8080

# Change password
argocd account update-password
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
└── falco.yaml               # Runtime security
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

- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [GitOps Principles](https://opengitops.dev/)
- [Kustomize](https://kustomize.io/)
