# DevSecOps Platform Template - Complete Project Overview

> **Purpose**: This document explains every component in this project and why it exists. Use this for interviews, presentations, or onboarding.

---

## 🎯 What is This Project?

This is a **production-ready DevSecOps framework** that demonstrates how to build secure, automated, and observable software delivery pipelines. It implements the "shift-left" security philosophy by integrating security at every stage of the SDLC.

### Key Goals

1. **Automate security** - Security scans run automatically, not manually
2. **Shift left** - Find issues early (in code) rather than late (in production)
3. **GitOps** - Infrastructure and deployments are code-driven
4. **Observable** - Know what's happening in your systems at all times

---

## 📁 Project Structure Explained

```
devsecops-platform-template/
│
├── .github/workflows/     # CI/CD Pipelines (GitHub Actions)
├── .pre-commit-config.yaml # Local security checks before commit
├── app/                   # Sample Node.js microservice
├── docs/                  # Documentation
├── infra/                 # Infrastructure as Code
│   ├── argocd/           # GitOps deployment definitions
│   ├── helm/             # Helm charts for observability
│   ├── k8s/              # Kubernetes manifests
│   └── terraform/        # Cloud infrastructure (AWS EKS)

├── security/             # Security tool configurations
└── Makefile              # Automation commands
```

---

## 🔒 SECURITY COMPONENTS

### 1. Pre-commit Hooks (`.pre-commit-config.yaml`)

**What**: Automated checks that run on your local machine BEFORE code is committed.

**Why**:

- Prevents secrets from ever entering git history
- Catches issues before they reach CI (faster feedback)
- Enforces code standards consistently across team

**Tools Included**:

| Tool | Purpose | Why This Tool? |
|------|---------|----------------|
| **Gitleaks** | Detects secrets (API keys, passwords) | Industry standard, fast, pattern-based |
| **detect-secrets** | Additional secret detection | Uses entropy analysis, catches different patterns |
| **ESLint** | JavaScript code quality | Finds bugs and security issues in JS |
| **Hadolint** | Dockerfile linting | Ensures Docker best practices |
| **Terraform fmt/validate** | IaC formatting and syntax | Consistent, valid Terraform code |

| **Kubeconform** | K8s manifest validation | Catches invalid YAML before apply |
| **Semgrep** | Static analysis (SAST) | Finds security vulnerabilities in code |
| **Commitizen** | Commit message format | Enforces conventional commits for changelog |

---

### 2. CI Security Scans (`.github/workflows/ci.yml`)

**What**: Automated security scans that run on every push/PR in GitHub Actions.

**Why**:

- Catches issues that slip past pre-commit
- Provides consistent, auditable security checks
- Blocks PRs with critical vulnerabilities

**Stages**:

```
┌─────────────┐   ┌─────────────┐   ┌─────────────┐   ┌─────────────┐
│   Secrets   │──▶│    SAST     │──▶│     SCA     │            │
│  Detection  │   │   Analysis  │   │Dependencies │            │
└─────────────┘   └─────────────┘   └─────────────┘   └─────────────┘
    Gitleaks         Semgrep          Trivy
```

| Scan Type | Tool | What It Finds |
|-----------|------|---------------|
| **Secrets** | Gitleaks, TruffleHog | Hardcoded passwords, API keys |
| **SAST** | Semgrep, CodeQL | SQL injection, XSS, insecure code patterns |
| **SCA** | Trivy, Snyk | Vulnerable dependencies (CVEs) |

| **Container** | Trivy, Grype | Vulnerable base images, packages |
| **License** | license-checker | GPL/copyleft license violations |

---

### 3. Dedicated Security Workflow (`.github/workflows/security.yml`)

**What**: A comprehensive security-focused workflow that runs daily and on-demand.

**Why**:

- New vulnerabilities are discovered daily
- Scheduled scans catch CVEs reported after initial deployment
- Provides security summary for compliance

---

### 4. Security Tool Configurations (`security/`)

**What**: Configuration files for each security tool.

| Folder | Tool | Purpose |
|--------|------|---------|
| `security/gitleaks/` | Gitleaks | Custom rules, allowlists |
| `security/semgrep/` | Semgrep | Custom SAST rules |
| `security/trivy/` | Trivy | Severity thresholds, ignore lists |


---

### 5. Supply Chain Security

**What**: Ensuring the software you deploy is exactly what you built.

**Components**:

| Component | Tool | Purpose |
|-----------|------|---------|
| **SBOM** | Syft | Software Bill of Materials - lists all components |
| **Image Signing** | Cosign (Sigstore) | Cryptographically signs container images |
| **Verification** | Cosign | Verifies signature before deployment |

**Why This Matters**:

- SolarWinds attack: Malicious code inserted into build
- Log4Shell: Need to know if you're affected
- SBOM is now required for US government software

---

### 6. Runtime Security (`runtime/`)

**What**: Security controls that run IN the Kubernetes cluster.





---

## 🚀 CI/CD PIPELINES

### 1. CI Pipeline (`.github/workflows/ci.yml`)

**Stages**:

```
1. Test & Lint
   ├── Install dependencies
   ├── Run linter
   └── Run unit tests with coverage

2. Security Scans (parallel)
   ├── Secrets scan (Gitleaks)
   ├── SAST scan (Semgrep)
   ├── Dependency scan (Trivy)
   └── IaC scan (Checkov)

3. Build & Scan Image
   ├── Build Docker image
   ├── Push to registry
   └── Scan image (Trivy)

4. SBOM & Sign
   ├── Generate SBOM (Syft)
   ├── Sign image (Cosign)
   └── Attach SBOM to image
```

---

### 2. CD Pipeline (`.github/workflows/cd.yml`)

**What**: Continuous Deployment using GitOps principles.

**Flow**:

```
Tag Push (v1.0.0)
       │
       ▼
┌──────────────┐
│ Verify Image │◄── Check Cosign signature
│   Signature  │
└──────┬───────┘
       │
       ▼
┌──────────────┐
│Update K8s    │◄── Kustomize updates image tag
│  Manifests   │
└──────┬───────┘
       │
       ▼
┌──────────────┐
│  ArgoCD      │◄── Detects git change, syncs to cluster
│    Sync      │
└──────┬───────┘
       │
       ▼
┌──────────────┐
│ Smoke Tests  │◄── Verify deployment works
└──────┬───────┘
       │
       ▼ (on tag only, with approval)
┌──────────────┐
│  Production  │◄── Manual approval required
│   Deploy     │
└──────────────┘
```

**Why GitOps?**

- Git is the source of truth
- Every change is auditable
- Easy rollbacks (git revert)
- Declarative, not imperative

---

### 3. Terraform Pipeline (`.github/workflows/terraform.yml`)

**What**: Infrastructure changes managed through PRs.

**Why**:

- Infrastructure changes are reviewed like code
- `terraform plan` shows what will change
- Apply only after PR approval

---

## ☸️ KUBERNETES COMPONENTS

### 1. Base Manifests (`infra/k8s/base/`)

| File | Purpose | Why? |
|------|---------|------|
| `deployment.yaml` | Pod specification | Defines how app runs |
| `service.yaml` | Internal networking | Allows pods to communicate |
| `serviceaccount.yaml` | Pod identity | Principle of least privilege |
| `hpa.yaml` | Horizontal Pod Autoscaler | Scale based on load |
| `pdb.yaml` | Pod Disruption Budget | Ensure availability during updates |
| `networkpolicy.yaml` | Network rules | Zero-trust networking |
| `servicemonitor.yaml` | Prometheus scraping | Metrics collection |
| `grafana-dashboard.yaml` | Dashboard definition | Pre-configured monitoring |

### 2. Kustomize Overlays (`infra/k8s/overlays/`)

**What**: Environment-specific configurations.

```
base/           ◄── Common configuration
  │
  ├── overlays/dev/    ◄── Development overrides
  │     └── Lower resources, fewer replicas
  │
  └── overlays/prod/   ◄── Production overrides
        └── Higher resources, more replicas, ingress
```

**Why Kustomize?**

- No templating complexity (unlike Helm)
- Base + patches = clear inheritance
- Native kubectl support

---

### 3. ArgoCD Applications (`infra/argocd/`)

**What**: GitOps application definitions.

| File | Purpose |
|------|---------|
| `root-app.yaml` | App-of-Apps pattern - manages all other apps |
| `apps/user-service-dev.yaml` | Dev deployment of user-service |
| `apps/user-service-prod.yaml` | Prod deployment of user-service |
| `apps/observability.yaml` | Observability stack (Prometheus, Loki) |


**App-of-Apps Pattern**:

```
root-app
    │
    ├── user-service-dev
    ├── user-service-prod
    ├── observability-stack
    │       ├── kube-prometheus-stack
    │       └── loki-stack
```

---

## 📊 OBSERVABILITY STACK

### Why Observability?

You can't secure or fix what you can't see. Observability answers:

- **Metrics**: Is the system healthy? (Prometheus)
- **Logs**: What happened? (Loki)


### Components

| Component | Tool | Purpose |
|-----------|------|---------|
| **Metrics** | Prometheus | Collects numeric data (CPU, requests, errors) |
| **Visualization** | Grafana | Dashboards and alerting UI |
| **Logs** | Loki | Aggregates logs from all pods |
| **Log Collection** | Promtail | Ships logs to Loki |
| **Alerting** | Alertmanager | Routes alerts to Slack/PagerDuty |


### How They Work Together

```
Application Pod
      │
      ├──[metrics]──▶ Prometheus ──▶ Grafana Dashboard
      │                    │
      │                    ▼
      │              Alertmanager ──▶ Slack/PagerDuty
      │
      └──[logs]────▶ Promtail ──▶ Loki ──▶ Grafana Explore
```

### Files Added

| File | Purpose |
|------|---------|
| `infra/argocd/apps/observability/kube-prometheus-stack.yaml` | Prometheus + Grafana + Alertmanager |
| `infra/argocd/apps/observability/loki-stack.yaml` | Log aggregation |

| `infra/helm/charts/observability/values.yaml` | Default configuration |
| `infra/helm/charts/observability/values-dev.yaml` | Dev (lightweight) config |
| `infra/helm/charts/observability/values-prod.yaml` | Prod (HA) config |
| `infra/k8s/base/servicemonitor.yaml` | Prometheus auto-discovery |
| `infra/k8s/base/grafana-dashboard.yaml` | Pre-built dashboard |

---

## 🐳 CONTAINER BEST PRACTICES

The Dockerfile (`app/Dockerfile`) demonstrates security best practices:

| Practice | Implementation | Why? |
|----------|---------------|------|
| **Multi-stage build** | 3 stages (deps, builder, production) | Smaller image, no build tools in prod |
| **Non-root user** | `USER nodeuser` (UID 1001) | Limits damage if container compromised |
| **Minimal base image** | `node:24-alpine` | Fewer packages = smaller attack surface |
| **Read-only filesystem** | `readOnlyRootFilesystem: true` | Prevents malware from writing files |
| **Drop capabilities** | `drop: [ALL]` | Remove Linux kernel capabilities |
| **Health checks** | `HEALTHCHECK` instruction | Kubernetes knows if app is healthy |
| **Signal handling** | `dumb-init` | Proper PID 1, handles SIGTERM correctly |

---

## 🏗️ INFRASTRUCTURE AS CODE

### Terraform Modules (`infra/terraform/`)

| Module | Purpose |
|--------|---------|
| `modules/eks/` | AWS EKS cluster |
| `environments/dev/` | Dev environment configuration |

**Why Terraform?**

- Reproducible infrastructure
- Version controlled
- Plan before apply
- Multi-cloud support

---

## 🛠️ AUTOMATION (Makefile)

The Makefile provides one-command automation:

| Category | Commands |
|----------|----------|
| **Development** | `make init`, `make dev`, `make build`, `make test` |
| **Security** | `make security-scan`, `make scan-secrets`, `make scan-sast` |
| **Docker** | `make docker-build`, `make docker-push`, `make sbom`, `make sign-image` |
| **Infrastructure** | `make infra-plan`, `make infra-apply` |
| **Kubernetes** | `make k8s-dev`, `make k8s-prod` |
| **GitOps** | `make deploy-argocd`, `make argocd-sync` |
| **Pre-commit** | `make pre-commit-install`, `make pre-commit-run` |
| **Observability** | `make observability-install`, `make observability-argocd` |

---

## 🔄 THE COMPLETE PIPELINE FLOW

```
Developer writes code
        │
        ▼
┌─────────────────┐
│  Pre-commit     │ ◄── Secrets checked, code linted
│     Hooks       │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│   Git Push      │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  CI Pipeline    │ ◄── Tests, SAST, SCA, Container scan
│  (GitHub       │
│   Actions)      │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Build & Sign   │ ◄── Docker build, SBOM, Cosign signature
│     Image       │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│   CD Pipeline   │ ◄── Update manifests, trigger ArgoCD
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│    ArgoCD       │ ◄── Syncs desired state to cluster
│   (GitOps)      │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│   Kubernetes    │ ◄── OPA Gatekeeper validates
│    Cluster      │     Falco monitors runtime
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Observability  │ ◄── Prometheus metrics, Loki logs
│     Stack       │     Grafana dashboards, Alerts
└─────────────────┘
```

---

## 📋 SUMMARY: WHY EACH COMPONENT EXISTS

| Component | The Problem | The Solution |
|-----------|-------------|--------------|
| Pre-commit hooks | Secrets committed to git | Catch before commit |
| Gitleaks/TruffleHog | API keys in code | Pattern + signature detection |
| Semgrep/CodeQL | Vulnerable code patterns | SAST scanning |
| Trivy | Vulnerable dependencies | SCA + container scanning |

| Syft | Don't know what's deployed | SBOM generation |
| Cosign | Tampered images | Cryptographic signing |

| ArgoCD | Manual deployments, drift | GitOps automation |
| Kustomize | Environment differences | Overlay-based config |
| Prometheus | Blind to system health | Metrics collection |
| Loki | Scattered logs | Centralized logging |
| Grafana | No visibility | Unified dashboards |
| Alertmanager | Miss critical issues | Automated alerting |

---

## 🎓 KEY CONCEPTS TO EXPLAIN

### 1. Shift Left

Move security earlier in the development process. Finding a bug in production costs 100x more than finding it in development.

### 2. Defense in Depth

Multiple layers of security. If one fails, others still protect you.

### 3. GitOps

Git is the single source of truth. All changes through Git, automated reconciliation.

### 4. Infrastructure as Code

Infrastructure defined in code, version controlled, reviewed, reproducible.

### 5. Zero Trust

Never trust, always verify. Even internal traffic is authenticated and authorized.

### 6. Observability

The ability to understand internal system state from external outputs (metrics, logs, traces).

---

*This document was generated as part of the DevSecOps Platform Template project.*
