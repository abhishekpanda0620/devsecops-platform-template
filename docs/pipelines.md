# Pipelines Documentation

This document provides detailed documentation for all CI/CD pipelines in the DevSecOps Platform Template.

## Pipeline Overview

| Pipeline | Trigger | Purpose |
|----------|---------|---------|
| `ci.yml` | Push/PR | Main CI with security scans |
| `cd.yml` | Tags/Manual | GitOps deployment |
| `security.yml` | Schedule/Manual | Comprehensive security scans |
| `terraform.yml` | Push to infra/ | Infrastructure changes |
| `eol-check.yml` | Schedule/Push/PR | EOL technology detection |

## CI Pipeline (`ci.yml`)

### Trigger

```yaml
on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main, develop]
```

### Stages

```
┌─────────────────────────────────────────────────────────────────┐
│                        CI Pipeline                               │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌───────┐ │
│  │  Test   │  │ Secrets │  │  SAST   │  │   SCA   │            │
│  │  Lint   │  │  Scan   │  │  Scan   │  │  Scan   │            │
│  └────┬────┘  └────┬────┘  └────┬────┘  └────┬────┘            │
│       │            │            │            │           │      │
│       └────────────┴────────────┴────────────┴───────────┘      │
│                                 │                                │
│                                 ▼                                │
│                          ┌───────────┐                          │
│                          │   Build   │                          │
│                          │   Image   │                          │
│                          └─────┬─────┘                          │
│                                │                                 │
│                                ▼                                 │
│                    ┌───────────────────────┐                    │
│                    │  Image Scan + SBOM    │                    │
│                    │  + Sign               │                    │
│                    └───────────────────────┘                    │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Jobs Detail

#### 1. Test & Lint
- Runs unit tests with Jest
- Uploads coverage report
- Runs ESLint

![CI Pipeline Summary](../screenshots/ci-pipeline-summary.png)

#### 2. Secrets Scan (Gitleaks)
- Scans entire git history
- Uses custom configuration
- Fails on any secret detected

#### 3. SAST Scan (Semgrep)
- Runs auto and security-audit configs
- Includes Node.js specific rules
- Outputs JSON report

#### 4. Dependency Scan (Trivy)
- Scans filesystem for vulnerabilities
- Uploads SARIF to GitHub Security
- Fails on CRITICAL findings

#### 5. Build & Sign
- Builds multi-architecture image
- Pushes to GHCR
- Signs with Cosign (keyless)
- Generates and attaches SBOM



### Artifacts

| Artifact | Retention | Purpose |
|----------|-----------|---------|
| coverage-report | 7 days | Test coverage |
| semgrep-results | 30 days | SAST findings |
| sbom | 90 days | Software bill of materials |

## CD Pipeline (`cd.yml`)

### Trigger

```yaml
on:
  push:
    tags:
      - 'v*'
  workflow_dispatch:
    inputs:
      environment: [dev, staging, prod]
      version: string
```

### Stages

```
┌─────────────────────────────────────────────────────────────────┐
│                        CD Pipeline                               │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐  │
│  │ Prepare  │───▶│  Verify  │───▶│  Update  │───▶│  Smoke   │  │
│  │  Params  │    │  Image   │    │ Manifests│    │  Tests   │  │
│  └──────────┘    └──────────┘    └──────────┘    └──────────┘  │
│                                                         │        │
│                        ┌────────────────────────────────┤        │
│                        │                                │        │
│                        ▼                                ▼        │
│         [staging passes]                     [staging fails]    │
│                        │                                │        │
│                        ▼                                ▼        │
│              ┌──────────────┐               ┌──────────────┐    │
│              │   Deploy     │               │   Rollback   │    │
│              │   to Prod    │               │              │    │
│              │  (approval)  │               └──────────────┘    │
│              └──────────────┘                                    │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Environment Promotion

1. **Tag Push** → Deploys to staging automatically
2. **Smoke Tests** → Validates deployment
3. **Manual Approval** → Required for production
4. **Production Deploy** → Updates prod manifests
5. **ArgoCD Sync** → Applies changes

### Rollback

Automatic rollback triggered when:
- Smoke tests fail
- Health checks fail

```bash
# Manual rollback
argocd app rollback user-service
```

## Security Pipeline (`security.yml`)

### Trigger

```yaml
on:
  schedule:
    - cron: '0 2 * * *'  # Daily at 2 AM UTC
  workflow_dispatch:
  push:
    branches: [main]
    paths:
      - 'app/**'
      - 'infra/**'
      - 'security/**'
```

### Additional Scans

| Scan | Tool | Purpose |
|------|------|---------|
| TruffleHog | Secret detection | Verified secrets only |
| CodeQL | SAST | GitHub's semantic analysis |
| Grype | Container scan | Alternative to Trivy |

| License check | npm license-checker | License compliance |

![Security Scan Summary](../screenshots/ci-security-scan-summary.png)

### SARIF Integration

All scan results are uploaded to GitHub Security tab in SARIF format:

- Code scanning alerts
- Dependency alerts
- Secret scanning alerts

## Terraform Pipeline (`terraform.yml`)

### Trigger

```yaml
on:
  push:
    branches: [main]
    paths:
      - 'infra/terraform/**'
  pull_request:
    paths:
      - 'infra/terraform/**'
  workflow_dispatch:
    inputs:
      action: [plan, apply, destroy]
      environment: [dev, staging, prod]
```

### Stages

1. **Validate** - Format and validate

3. **Plan** - Generate execution plan
4. **Apply** - Apply changes (with approval)
5. **Destroy** - Destroy resources (with approval)

### PR Comments

Plan output is posted as PR comment:

```
#### Terraform Plan for `dev` 📋

<details>
<summary>Show Plan</summary>

```terraform
+ aws_eks_cluster.main
+ aws_eks_node_group.main
...
```

</details>
```

## EOL Check Pipeline (`eol-check.yml`)

### Trigger

```yaml
on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main, develop]
  schedule:
    - cron: '0 9 * * 1'  # Weekly on Monday
```

### Features

1. **Technology Scanning** - Scans for EOL Node.js, Docker, databases
2. **AI Model Check** - Scans for deprecated AI models
3. **HTML Report** - Generates detailed report
4. **Auto-Issue Creation** - Creates GitHub issue for EOL findings
5. **PR Blocking** - Optionally fails on EOL technologies

### Output

```
┌────────────────────────────────────────────────────────────────┐
│ Technology      │ Version │ EOL Date   │ Status               │
├─────────────────┼─────────┼────────────┼──────────────────────┤
│ Node.js         │ 20.0.0  │ 2026-04-30 │ ✅ Supported         │
│ Docker          │ 24.0.0  │ N/A        │ ✅ Supported         │
│ PostgreSQL      │ 14.0    │ 2026-11-12 │ ⚠️  Approaching EOL  │
└────────────────────────────────────────────────────────────────┘
```

![EOL Check Summary](../screenshots/ci-eol-check-summary.png)

## Pipeline Best Practices

### Security

1. **Pin action versions to SHA**
   ```yaml
   uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11  # v4.1.1
   ```

2. **Use OIDC for cloud auth**
   ```yaml
   - uses: aws-actions/configure-aws-credentials@v4
     with:
       role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
   ```

3. **Minimal permissions**
   ```yaml
   permissions:
     contents: read
     packages: write
   ```

### Performance

1. **Use caching**
   ```yaml
   - uses: actions/cache@v4
     with:
       path: ~/.npm
       key: npm-${{ hashFiles('**/package-lock.json') }}
   ```

2. **Parallel jobs**
   - Security scans run in parallel
   - Use `needs` for dependencies

3. **Cancel in-progress**
   ```yaml
   concurrency:
     group: ci-${{ github.ref }}
     cancel-in-progress: true
   ```

### Reliability

1. **Retry mechanisms**
   ```yaml
   retry:
     limit: 3
     backoff:
       duration: 5s
       factor: 2
   ```

2. **Timeouts**
   ```yaml
   timeout-minutes: 30
   ```

3. **Continue on error for non-blocking**
   ```yaml
   continue-on-error: true
   ```

## Customization

### Adding New Scans

1. Create new job in appropriate workflow
2. Use existing patterns for SARIF upload
3. Add to summary job
4. Update documentation

### Modifying Gates

Edit the job conditions and exit codes:

```yaml
- name: Check results
  run: |
    if [ "${{ steps.scan.outputs.critical }}" -gt 0 ]; then
      exit 1
    fi
```

## Monitoring

### GitHub Actions Insights

- View workflow runs
- Check job durations
- Monitor failure rates

### Notifications

Configure notifications in repository settings:
- Email on failure
- Slack integration
- MS Teams webhook
