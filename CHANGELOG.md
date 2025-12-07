# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Initial project structure
- Sample Node.js microservice with Express.js
- Comprehensive CI/CD pipelines (ci.yml, cd.yml, security.yml, terraform.yml)
- EOL technology check workflow integration
- Security scanning tools configuration (Gitleaks, Semgrep, Trivy, Checkov)
- Terraform EKS module with security best practices
- Kubernetes manifests with Kustomize overlays
- ArgoCD GitOps configuration (App of Apps pattern)
- Runtime security with Falco and OPA Gatekeeper
- Monitoring stack integration (Prometheus, Grafana, Loki)
- SBOM generation and image signing with Cosign
- Comprehensive documentation

### Security
- Multi-stage Dockerfile with non-root user
- Pod security context with privilege restrictions
- Network policies for namespace isolation
- Resource limits enforcement via Gatekeeper
- Trusted registry validation
- Secret scanning in CI pipeline
- EOL technology detection

## [0.1.0] - 2024-12-06

### Added
- Initial release
- MVP features as defined in ROADMAP.md

[Unreleased]: https://github.com/yourusername/devsecops-platform-template/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/yourusername/devsecops-platform-template/releases/tag/v0.1.0
