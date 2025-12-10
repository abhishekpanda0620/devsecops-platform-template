# Pre-commit Hooks

This document describes the pre-commit hooks configured for the DevSecOps Platform Template.

## Overview

Pre-commit hooks enforce code quality and security standards before code is committed, implementing the "shift-left" security principle.

## Quick Start

### Installation

```bash
# Install pre-commit and hooks
make pre-commit-install

# Or manually:
pip install pre-commit
pre-commit install
pre-commit install --hook-type commit-msg
```

### Running Checks

```bash
# Run on all files
make pre-commit-run
# or
pre-commit run --all-files

# Run on staged files only (happens automatically on commit)
pre-commit run
```

### Updating Hooks

```bash
make pre-commit-update
# or
pre-commit autoupdate
```

## Configured Hooks

### General Checks

| Hook | Description |
|------|-------------|
| `trailing-whitespace` | Trims trailing whitespace |
| `end-of-file-fixer` | Ensures files end with newline |
| `check-yaml` | Validates YAML syntax |
| `check-json` | Validates JSON syntax |
| `check-added-large-files` | Prevents large files (>1MB) |
| `check-merge-conflict` | Detects merge conflict markers |
| `detect-private-key` | Detects private keys |
| `mixed-line-ending` | Fixes line endings to LF |

### Security - Secret Detection

| Hook | Description |
|------|-------------|
| `gitleaks` | Detects secrets using pattern matching |
| `detect-secrets` | Yelp's entropy-based secret detection |

**Managing False Positives:**

Update `.secrets.baseline` to mark known false positives:
```bash
detect-secrets scan --baseline .secrets.baseline
```

### JavaScript/Node.js

| Hook | Description |
|------|-------------|
| `eslint` | Lints and auto-fixes JavaScript |

### Terraform/IaC

| Hook | Description |
|------|-------------|
| `terraform_fmt` | Formats Terraform files |
| `terraform_validate` | Validates Terraform syntax |
| `terraform_docs` | Generates Terraform documentation |
| `terraform_tflint` | Lints Terraform files |
| `checkov` | IaC security scanning (on push) |

### Kubernetes/YAML

| Hook | Description |
|------|-------------|
| `kubeconform` | Validates Kubernetes manifests |

### Docker

| Hook | Description |
|------|-------------|
| `hadolint` | Lints Dockerfiles |

### Documentation

| Hook | Description |
|------|-------------|
| `markdownlint` | Lints Markdown files |

### Commit Messages

| Hook | Description |
|------|-------------|
| `commitizen` | Enforces conventional commits |

### SAST (Push Only)

| Hook | Description |
|------|-------------|
| `semgrep` | Static analysis security testing |

## Hook Stages

Hooks run at different stages:

| Stage | When | Hooks |
|-------|------|-------|
| `pre-commit` | Before commit | All except SAST |
| `commit-msg` | After commit message | commitizen |
| `pre-push` | Before push | checkov, semgrep |

## Conventional Commits

We use [Conventional Commits](https://www.conventionalcommits.org/) format:

```
<type>[optional scope]: <description>

[optional body]

[optional footer(s)]
```

### Types

| Type | Description |
|------|-------------|
| `feat` | New feature |
| `fix` | Bug fix |
| `docs` | Documentation |
| `style` | Formatting (no code change) |
| `refactor` | Refactoring |
| `test` | Adding tests |
| `chore` | Maintenance |
| `ci` | CI/CD changes |
| `security` | Security fixes |

### Examples

```bash
# Feature
git commit -m "feat(api): add user authentication endpoint"

# Bug fix
git commit -m "fix(auth): resolve token expiration issue"

# Breaking change
git commit -m "feat(api)!: change response format for users endpoint"
```

## Skipping Hooks

### Skip All Hooks (Emergency Only)

```bash
git commit --no-verify -m "emergency fix"
```

### Skip Specific Hook

```bash
SKIP=eslint git commit -m "fix: quick typo"

# Skip multiple
SKIP=eslint,terraform_fmt git commit -m "fix: config update"
```

## CI Integration

Pre-commit hooks also run in CI via [pre-commit.ci](https://pre-commit.ci):

```yaml
# In .pre-commit-config.yaml
ci:
  autofix_commit_msg: |
    [pre-commit.ci] auto fixes from pre-commit.com hooks
  autofix_prs: true
  autoupdate_branch: 'develop'
  autoupdate_schedule: monthly
  skip: [checkov, semgrep]  # Skip slow hooks in CI
```

## Troubleshooting

### Hook Installation Issues

```bash
# Reinstall hooks
pre-commit uninstall
pre-commit clean
pre-commit install --install-hooks

# Update hook versions
pre-commit autoupdate
```

### Specific Hook Failures

**Gitleaks false positive:**
```yaml
# Add to .gitleaks.toml
[[rules]]
description = "Allow test data"
regex = '''test-api-key'''
allowlist = true
```

**Terraform validation:**
```bash
# Initialize Terraform first
cd infra/terraform/environments/dev
terraform init
```

**Kubeconform with CRDs:**
```bash
# Download CRD schemas
kubeconform -schema-location default \
  -schema-location 'https://raw.githubusercontent.com/datreeio/CRDs-catalog/main/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json'
```

### Performance

For large repositories, consider:

```yaml
# In .pre-commit-config.yaml
default_stages: [commit]
fail_fast: true  # Stop on first failure

# Use 'manual' stage for slow hooks
- id: checkov
  stages: [manual]  # Run with: pre-commit run --hook-stage manual
```

## Configuration Files

| File | Purpose |
|------|---------|
| `.pre-commit-config.yaml` | Hook configuration |
| `.secrets.baseline` | Known false positives for detect-secrets |
| `.gitleaks.toml` | Gitleaks configuration (if exists) |
| `.hadolint.yaml` | Hadolint configuration (if exists) |
| `.markdownlint.json` | Markdownlint rules (if exists) |
