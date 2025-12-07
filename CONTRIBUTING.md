# Contributing to DevSecOps Platform Template

Thank you for your interest in contributing! This document provides guidelines for contributing to the project.

## Code of Conduct

By participating in this project, you agree to maintain a respectful and inclusive environment.

## How to Contribute

### Reporting Issues

1. Check if the issue already exists
2. Use the issue template
3. Provide as much detail as possible:
   - Steps to reproduce
   - Expected vs actual behavior
   - Environment details

### Suggesting Features

1. Open a feature request issue
2. Describe the use case
3. Explain the proposed solution
4. Consider security implications

### Submitting Pull Requests

1. Fork the repository
2. Create a feature branch from `main`
3. Make your changes
4. Run tests and security scans
5. Submit a pull request

## Development Setup

```bash
# Clone your fork
git clone https://github.com/YOUR_USERNAME/devsecops-platform-template.git
cd devsecops-platform-template

# Initialize environment
make init

# Start development server
make dev

# Run tests
make test

# Run security scans
make security-scan
```

## Code Standards

### JavaScript/Node.js

- Use ESLint configuration
- Write unit tests for new features
- Follow Express.js best practices
- Implement proper error handling

### Terraform

- Format with `terraform fmt`
- Validate with `terraform validate`
- Pass Checkov scans
- Document variables and outputs

### Kubernetes

- Use Kustomize for overlays
- Include resource limits
- Follow security best practices
- Test with `kubectl apply --dry-run`

### GitHub Actions

- Pin actions to SHA
- Use minimal permissions
- Include error handling
- Document workflow steps

## Security Requirements

All contributions must:

1. **Pass security scans** - No secrets, vulnerabilities, or misconfigurations
2. **Follow least privilege** - Minimal permissions
3. **Include tests** - Security-relevant code paths
4. **Update documentation** - Security considerations

### Pre-commit Checks

Before committing:

```bash
# Run all checks
make test
make lint
make security-scan
make scan-eol
```

## Pull Request Process

1. **Title**: Use conventional commits format
   - `feat:` New feature
   - `fix:` Bug fix
   - `docs:` Documentation
   - `security:` Security improvement
   - `chore:` Maintenance

2. **Description**: Use the PR template
   - What does this change?
   - Why is it needed?
   - How was it tested?
   - Security considerations?

3. **Checks**: All CI checks must pass
   - Tests
   - Linting
   - Security scans
   - Build

4. **Review**: At least one maintainer approval

## Branch Strategy

```
main (protected)
├── feature/add-new-scanner
├── fix/security-vulnerability
└── docs/update-readme
```

## Testing

### Unit Tests

```bash
cd app && npm test
```

### Integration Tests

```bash
docker-compose up -d
make test-integration
```

### Security Tests

```bash
make security-scan
```

## Documentation

- Update README.md for user-facing changes
- Update docs/ for detailed documentation
- Include inline comments for complex code
- Update CHANGELOG.md

## Release Process

1. Update version in package.json
2. Update CHANGELOG.md
3. Create PR to main
4. After merge, create release tag
5. GitHub Actions will publish

## Getting Help

- Open a discussion for questions
- Join community chat
- Review existing issues and PRs

## Recognition

Contributors are listed in:
- README.md contributors section
- CHANGELOG.md for each release
- GitHub contributors page

Thank you for contributing to making software more secure! 🛡️
