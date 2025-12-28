# Security Guide

This document describes the security controls, policies, and best practices implemented in the DevSecOps Platform Template.

## Security Overview

The platform implements a **defense-in-depth** approach with security controls at every stage of the software development lifecycle.

## Security Scanning Tools

### 1. Secret Detection (Gitleaks)

**Purpose:** Detect hardcoded secrets, API keys, and credentials in source code.

**Configuration:** `security/gitleaks/.gitleaks.toml`

**Usage:**
```bash
# Run locally
make scan-secrets

# CI/CD
# Runs automatically on every PR
```

**What it detects:**
- AWS credentials
- API keys
- Private keys
- JWT tokens
- Database connection strings
- Slack webhooks

### 2. Static Application Security Testing (Semgrep)

**Purpose:** Find security vulnerabilities and code quality issues through static analysis.

**Configuration:** `security/semgrep/rules.yaml`

**Custom Rules:**
- SQL injection detection
- XSS prevention
- Command injection
- Path traversal
- Insecure cryptography
- Hardcoded secrets

**Usage:**
```bash
# Run locally
make scan-sast

# With specific rules
docker run --rm -v $(PWD):/src semgrep/semgrep --config=security/semgrep/rules.yaml /src
```

### 3. Software Composition Analysis (Trivy)

**Purpose:** Scan dependencies for known vulnerabilities.

**Configuration:** `security/trivy/trivy.yaml`

**Scans:**
- OS packages
- Application dependencies (npm, pip, etc.)
- Container images
- IaC misconfigurations

**Usage:**
```bash
# Dependency scan
make scan-deps

# Container scan
make scan-container
```

### 4. End-of-Life Technology Detection (eol-check)

**Purpose:** Identify technologies that have reached end-of-life and are no longer receiving security updates.

**Usage:**
```bash
# Run locally
make scan-eol

# Or directly
npx eol-check --format table
```

**What it checks:**
- Node.js versions
- Docker base images
- Database versions
- Operating systems
- AI model deprecations



### 6. Container Image Signing (Cosign)

**Purpose:** Sign container images to ensure supply chain integrity.

**Usage:**
```bash
# Sign image
make sign-image

# Verify signature
cosign verify ghcr.io/abhishekpanda0620/devsecops-platform-template/user-service:latest
```

### 7. SBOM Generation (Syft)

**Purpose:** Generate Software Bill of Materials for transparency and compliance.

**Formats:**
- SPDX JSON
- CycloneDX JSON

**Usage:**
```bash
make sbom
```

## Kubernetes Security

### Pod Security

All pods are configured with:

```yaml
securityContext:
  runAsNonRoot: true
  runAsUser: 1001
  fsGroup: 1001
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: true
  capabilities:
    drop:
      - ALL
```

### Network Policies

Default deny with explicit allow rules:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
spec:
  policyTypes:
    - Ingress
    - Egress
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              name: ingress-nginx
```

### Resource Limits

All containers must specify resource requests and limits:

```yaml
resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 500m
    memory: 512Mi
```





## Secrets Management

### Best Practices

1. **Never store secrets in Git**
2. **Use GitHub Actions secrets for CI/CD**
3. **Use Kubernetes secrets with encryption at rest**
4. **Consider external secret managers:**
   - AWS Secrets Manager
   - HashiCorp Vault
   - SOPS

### Example: External Secrets

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: app-secrets
spec:
  secretStoreRef:
    name: aws-secrets-manager
    kind: ClusterSecretStore
  target:
    name: app-secrets
  data:
    - secretKey: DATABASE_URL
      remoteRef:
        key: production/database
        property: url
```

## Application Security

### Express.js Security Middleware

The sample application includes:

```javascript
// Helmet - HTTP security headers
app.use(helmet());

// CORS - Cross-origin resource sharing
app.use(cors({
  origin: process.env.ALLOWED_ORIGINS
}));

// Rate limiting - DoS protection
app.use(rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 100
}));

// Input validation
app.use(express.json({ limit: '10kb' }));
```

### Input Validation

All user input is validated using express-validator:

```javascript
const userValidation = [
  body('email').isEmail().normalizeEmail(),
  body('name').trim().isLength({ min: 2, max: 100 }),
  body('role').optional().isIn(['user', 'admin'])
];
```

## CI/CD Security

### GitHub Actions Security

1. **Least privilege secrets**
2. **Pin action versions to SHA**
3. **Use OIDC for cloud authentication**
4. **Scan workflows with actionlint**

### Security Gates

The CI pipeline enforces these gates:

| Gate | Fail Condition |
|------|----------------|
| Secrets scan | Any secret detected |
| SAST | HIGH/CRITICAL findings |
| Dependency scan | CRITICAL vulnerabilities |
| Container scan | CRITICAL vulnerabilities |

| EOL check | EOL technologies in use |

## Compliance

### SLSA Levels

This template helps achieve SLSA Level 2+:

| Requirement | Implementation |
|-------------|---------------|
| Version controlled | Git + GitHub |
| Verified history | Signed commits |
| Retained indefinitely | GitHub retention |
| Two-person reviewed | PR requirements |
| Automated build | GitHub Actions |
| Provenance | SBOM + attestations |
| Signed artifacts | Cosign |

### Security Audit Checklist

- [ ] All secrets rotated regularly
- [ ] Dependencies updated and scanned
- [ ] Container images rebuilt weekly

- [ ] Access logs reviewed
- [ ] Network policies tested
- [ ] Backup recovery tested

## Security Incident Response

### Detection

1. **Gitleaks alert** - Secret in repository
2. **Semgrep alert** - Code vulnerability
3. **Trivy alert** - CVE in dependency/image
4. **EOL check alert** - Unsupported technology

### Response

1. **Assess severity** - CRITICAL, HIGH, MEDIUM, LOW
2. **Contain threat** - Isolate affected systems
3. **Investigate** - Determine root cause
4. **Remediate** - Fix vulnerability
5. **Document** - Create incident report
6. **Improve** - Update policies/procedures

## References

- [OWASP Top 10](https://owasp.org/Top10/)
- [CIS Kubernetes Benchmark](https://www.cisecurity.org/benchmark/kubernetes)
- [SLSA Framework](https://slsa.dev/)
- [NIST Cybersecurity Framework](https://www.nist.gov/cyberframework)
