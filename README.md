# 🛡️ DevSecOps Platform Template

[![CI Pipeline](https://github.com/abhishekpanda0620/devsecops-platform-template/actions/workflows/ci.yml/badge.svg)](https://github.com/abhishekpanda0620/devsecops-platform-template/actions/workflows/ci.yml)
[![Security Scan](https://github.com/abhishekpanda0620/devsecops-platform-template/actions/workflows/security.yml/badge.svg)](https://github.com/abhishekpanda0620/devsecops-platform-template/actions/workflows/security.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A **production-ready, opinionated DevSecOps framework** that provides a complete CI/CD + security + GitOps + Kubernetes deployment template for any application.

---

## 🎯 Goals

- ✅ **End-to-end security automation** across the SDLC
- ✅ **Reusable CI/CD pipelines** and IaC modules
- ✅ **Runnable Kubernetes reference environment** (dev & prod overlays)
- ✅ **GitOps-first deployment model** with ArgoCD
- ✅ **Modular and easy to fork** for organizations

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              DevSecOps Pipeline                              │
├────────────────┬────────────────┬────────────────┬────────────────┬─────────┤
│   CODE         │   BUILD        │   SECURITY     │   DEPLOY       │ RUNTIME │
│                │                │                │                │         │
│ • Git Push     │ • Docker Build │ • Gitleaks     │ • ArgoCD Sync  │ • Falco │
│ • PR Review    │ • Unit Tests   │ • Semgrep      │ • K8s Apply    │ • OPA   │
│ • Lint         │ • SBOM Gen     │ • Trivy        │ • Smoke Tests  │ • Prom  │
│                │ • Image Sign   │ • Checkov      │ • Rollback     │ • Loki  │
└────────────────┴────────────────┴────────────────┴────────────────┴─────────┘
```

---

## 📂 Repository Structure

```
devsecops-platform-template/
│
├── .github/workflows/          # GitHub Actions CI/CD
│   ├── ci.yml                  # Main CI pipeline
│   ├── cd.yml                  # GitOps deployment
│   ├── security.yml            # Security scans
│   └── terraform.yml           # Infrastructure pipeline
│
├── app/                        # Sample microservice
│   ├── src/                    # Application source code
│   ├── tests/                  # Unit & integration tests
│   ├── Dockerfile              # Multi-stage Dockerfile
│   └── package.json            # Dependencies
│
├── security/                   # Security tools configuration
│   ├── semgrep/                # SAST rules
│   ├── gitleaks/               # Secret detection config
│   ├── trivy/                  # Container scanning
│   ├── syft/                   # SBOM generation
│   ├── cosign/                 # Image signing
│   └── checkov/                # IaC scanning
│
├── infra/                      # Infrastructure as Code
│   ├── terraform/              # Cloud modules (AWS/GCP/Azure)
│   ├── k8s/                    # Kubernetes manifests
│   ├── helm/                   # Helm charts
│   └── argocd/                 # GitOps manifests
│
├── runtime/                    # Runtime security
│   ├── falco/                  # Runtime detection
│   ├── opa-gatekeeper/         # Policy enforcement
│   └── monitoring/             # Observability stack
│
├── sbom/                       # Software Bill of Materials
├── docs/                       # Documentation
└── Makefile                    # Automation commands
```

---

## 🚀 Quick Start

### Prerequisites

- Docker & Docker Compose
- Node.js 24+ (for sample app)
- kubectl & helm (for K8s deployment)
- Terraform 1.14+ (for infrastructure)

### Local Development

```bash
# Clone the repository
git clone https://github.com/abhishekpanda0620/devsecops-platform-template.git
cd devsecops-platform-template

# Initialize the project
make init

# Start local development environment
make dev

# Run security checks locally
make security-scan

# Build and test
make build test
```

### Deploy to Kubernetes

```bash
# Deploy infrastructure (EKS)
make infra-plan
make infra-apply

# Deploy application via ArgoCD
make deploy-argocd
```

---

## 🔒 Security Features

| Tool | Purpose | Stage |
|------|---------|-------|
| **Gitleaks** | Secret detection | Pre-commit, CI |
| **Semgrep** | Static code analysis (SAST) | CI |
| **Trivy** | Vulnerability scanning (SCA, Container) | CI |
| **Syft** | SBOM generation | Build |
| **Cosign** | Image signing & verification | Build, Deploy |
| **Checkov** | Infrastructure as Code scanning | CI |
| **Falco** | Runtime threat detection | Runtime |
| **OPA Gatekeeper** | Kubernetes policy enforcement | Runtime |

---

## 📊 Observability Stack

- **Prometheus** — Metrics collection and alerting
- **Grafana** — Visualization dashboards
- **Loki** — Log aggregation
- **Alertmanager** — Alert routing and notifications

---

## 🔄 GitOps Workflow

```
┌──────────┐     ┌──────────┐     ┌──────────┐     ┌──────────┐
│   Dev    │ ──▶ │ Staging  │ ──▶ │   Prod   │ ──▶ │  Rollback│
│  (auto)  │     │  (auto)  │     │ (manual) │     │  (auto)  │
└──────────┘     └──────────┘     └──────────┘     └──────────┘
     │                │                │                │
     └────────────────┴────────────────┴────────────────┘
                         ArgoCD Sync
```

---

## 📚 Documentation

- [Architecture Overview](docs/architecture.md)
- [Pipeline Reference](docs/pipelines.md)
- [Security Guide](docs/security.md)
- [GitOps Setup](docs/gitops.md)
- [Setup Guide](docs/setup-guide.md)
- [Roadmap](docs/ROADMAP.md)

---

## 🤝 Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for contribution guidelines.

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## ⭐ Show Your Support

Give a ⭐️ if this project helped you!

---

*Built with ❤️ by the DevSecOps community*
