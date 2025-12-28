# Architecture Overview

This document describes the architecture of the DevSecOps Platform Template.

## System Architecture

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                                  DEVELOPER WORKFLOW                                 │
├─────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                     │
│   ┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐      │
│   │  Code    │───▶│   PR     │───▶│   CI     │───▶│  Build   │───▶│  Deploy  │      │
│   │  Commit  │    │  Review  │    │ Pipeline │    │  Image   │    │ (GitOps) │      │
│   └──────────┘    └──────────┘    └──────────┘    └──────────┘    └──────────┘      │
│                                                                                     │
│                           ┌─────────────┴─────────────┐                             │
│                           ▼                           ▼                             │
│                    ┌────────────┐            ┌────────────┐      ┌──────────┐       │
│                    │  Security  │            │   SBOM &   │      │  ArgoCD  │       │
│                    │   Scans    │            │   Sign     │      │   Sync   │       │
│                    └────────────┘            └────────────┘      └──────────┘       │
│                                                                                     │
└─────────────────────────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────────────────────────┐
│                                  KUBERNETES CLUSTER                                  │
├──────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                      │
│   ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐                      │
│   │   Application   │  │    Monitoring   │  │ Runtime Security │                     │
│   │   Namespace     │  │    Namespace    │  │    Namespace     │                     │
│   ├─────────────────┤  ├─────────────────┤  ├─────────────────┤                      │
│   │ • user-service  │  │ • Prometheus    │  │ • NetworkPolicy  │                     │
│   │ • HPA           │  │ • Grafana       │  │ • ServiceMonitor │                     │
│   │ • NetworkPolicy │  │ • Loki          │  │ • Network Policy │                     │
│   │ • PDB           │  │ • Alertmanager  │  │                  │                     │
│   └─────────────────┘  └─────────────────┘  └─────────────────┘                      │
│                                                                                      │
└──────────────────────────────────────────────────────────────────────────────────────┘
```

## Component Details

### 1. CI/CD Pipeline

The CI/CD pipeline is implemented using GitHub Actions and consists of the following stages:

| Stage | Purpose | Tools |
|-------|---------|-------|
| **Lint & Test** | Code quality and unit tests | ESLint, Jest |
| **Secret Scan** | Detect hardcoded secrets | Gitleaks |
| **SAST** | Static code analysis | Semgrep, CodeQL |
| **SCA** | Dependency vulnerability scan | Trivy |
| **EOL Check** | End-of-life technology detection | eol-check |
| **Build** | Docker image creation | Docker Buildx |
| **Image Scan** | Container vulnerability scan | Trivy, Grype |
| **SBOM** | Software bill of materials | Syft |
| **Sign** | Image signing | Cosign |
| **IaC Scan** | Infrastructure code scan | Checkov, tfsec |

### 2. GitOps Deployment

The platform supports **two GitOps approaches**:

| Approach | Best For | Setup Location |
|----------|----------|----------------|
| **AWS EKS Managed Argo CD** | AWS-only deployments | `infra/terraform/modules/eks-gitops/` |
| **Self-Managed ArgoCD** | Multi-cloud / On-prem | `infra/argocd/` |

```
┌──────────────────────────────────────────────────────────────────┐
│                       GitOps Flow                                │
├──────────────────────────────────────────────────────────────────┤
│                                                                  │
│   GitHub Repository          ArgoCD                 Kubernetes   │
│   ┌─────────────┐           ┌─────────┐           ┌───────────┐  │
│   │  Manifests  │──poll────▶│  Sync   │──deploy──▶│   Pods    │  │
│   │  (k8s/)     │           │  Engine │           │           │  │
│   └─────────────┘           └─────────┘           └───────────┘  │
│         │                         │                      │       │
│         │                         ▼                      │       │
│         │                   ┌─────────┐                  │       │
│         │                   │ Health  │◀─────────────────┘       │
│         │                   │ Check   │                          │
│         │                   └─────────┘                          │
│         │                         │                              │
│         │                         ▼                              │
│         │    ◀──rollback─── ┌─────────┐                          │
│         │                   │ Rollback│                          │
│         │                   │ on Fail │                          │
│         │                   └─────────┘                          │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
```

> **Note:** AWS EKS Managed Argo CD (announced at re:Invent 2024) provides AWS-managed
> upgrades, patching, and console integration. For multi-cloud deployments, use
> self-managed ArgoCD. See [gitops.md](gitops.md) for detailed setup instructions.


### 3. Security Layers

The platform implements defense-in-depth with multiple security layers:

```
┌──────────────────────────────────────────────────────────────────┐
│                      Security Layers                             │
├──────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Layer 1: Code Security                                          │
│  ├── Secret scanning (Gitleaks)                                  │
│  ├── SAST (Semgrep, CodeQL)                                      │
│  └── Dependency scanning (Trivy)                                 │
│                                                                  │
│  Layer 2: Build Security                                         │
│  ├── Container scanning (Trivy, Grype)                           │
│  ├── SBOM generation (Syft)                                      │
│  └── Image signing (Cosign)                                      │
│                                                                  │
│  Layer 3: Infrastructure Security                                │
│  ├── IaC scanning (Checkov, tfsec)                               │
│  ├── EOL technology detection (eol-check)                        │
│  └── Policy as Code (OPA Gatekeeper)                             │
│                                                                  │


│  └── Network policies                                            │
│                                                                  │
│  Layer 5: Observability                                          │
│  ├── Metrics (Prometheus)                                        │
│  ├── Logs (Loki)                                                 │
│  └── Dashboards (Grafana)                                        │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
```

### 4. Kubernetes Architecture

```yaml
Namespaces:
  dev:
    - user-service (1 replica, SPOT instances)
    - HorizontalPodAutoscaler (1-3 replicas)

  staging:
    - user-service (2 replicas)
    - HorizontalPodAutoscaler (2-5 replicas)

  prod:
    - user-service (3 replicas, ON_DEMAND instances)
    - HorizontalPodAutoscaler (3-20 replicas)
    - Ingress with TLS
    - Rate limiting

  monitoring:
    - Prometheus
    - Grafana
    - Loki
    - Alertmanager


    - Constraint Templates
```

### 5. AWS Infrastructure

```
┌─────────────────────────────────────────────────────────────────┐
│                         AWS Account                              │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │                          VPC                               │  │
│  │  ┌─────────────────┐  ┌─────────────────┐                 │  │
│  │  │ Public Subnet   │  │ Private Subnet  │                 │  │
│  │  │ ┌─────────────┐ │  │ ┌─────────────┐ │                 │  │
│  │  │ │   ALB/NLB   │ │  │ │ EKS Nodes   │ │                 │  │
│  │  │ └─────────────┘ │  │ └─────────────┘ │                 │  │
│  │  │ ┌─────────────┐ │  │ ┌─────────────┐ │                 │  │
│  │  │ │ NAT Gateway │ │  │ │   RDS       │ │                 │  │
│  │  │ └─────────────┘ │  │ └─────────────┘ │                 │  │
│  │  └─────────────────┘  └─────────────────┘                 │  │
│  │                                                            │  │
│  │  ┌─────────────────────────────────────────────────────┐  │  │
│  │  │                    EKS Cluster                       │  │  │
│  │  │  • Control Plane (AWS Managed)                       │  │  │
│  │  │  • Managed Node Groups                               │  │  │
│  │  │  • OIDC Provider for IRSA                           │  │  │
│  │  │  • KMS Encryption for Secrets                       │  │  │
│  │  └─────────────────────────────────────────────────────┘  │  │
│  └───────────────────────────────────────────────────────────┘  │
│                                                                  │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐           │
│  │     ECR      │  │      S3      │  │    KMS       │           │
│  │  (or GHCR)   │  │ (TF State)   │  │  (Secrets)   │           │
│  └──────────────┘  └──────────────┘  └──────────────┘           │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

## Data Flow

1. **Developer pushes code** → GitHub
2. **GitHub Actions triggers** → CI Pipeline
3. **Security scans run** → Secrets, SAST, SCA, IaC
4. **EOL check verifies** → Technologies are supported
5. **Docker image built** → Multi-stage, minimal
6. **Image scanned** → Trivy/Grype
7. **SBOM generated** → Syft (SPDX + CycloneDX)
8. **Image signed** → Cosign (keyless)
9. **Manifest updated** → Kustomize patches image tag
10. **ArgoCD syncs** → Detects change, deploys
11. **Pods deployed** → With security context
12. **Prometheus scrapes** → Metrics collection
13. **Grafana visualizes** → Dashboards

## Environment Promotion

```
dev → staging → prod
 │       │        │
 │       │        └── Manual approval required
 │       └── Auto-sync after passing smoke tests
 └── Auto-sync on merge to main branch
```

## References

- [ROADMAP.md](ROADMAP.md) - Project roadmap and phases
- [pipelines.md](pipelines.md) - Detailed pipeline documentation
- [security.md](security.md) - Security controls and policies
- [gitops.md](gitops.md) - GitOps setup and patterns
- [setup-guide.md](setup-guide.md) - Getting started guide
