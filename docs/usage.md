# ImageFoundry Documentation

## Table of Contents

1. [Getting Started](#getting-started)
2. [Configuration](#configuration)
3. [Templates](#templates)
4. [Security](#security)
5. [CI/CD Integration](#cicd-integration)
6. [Troubleshooting](#troubleshooting)

## Getting Started

### Prerequisites

- Docker with Buildx support
- Go 1.22+ (for building CLI)
- Git
- Make (optional)

### Quick Start

```bash
# Clone the repository
git clone https://github.com/simonbbbb/imagefoundry.git
cd imagefoundry

# Build the CLI
make build

# Initialize a new project
./build/foundry init

# Validate and build
./build/foundry validate
./build/foundry build
```

## Configuration

### Configuration File Structure

The `image-foundry.yaml` file controls all aspects of the build process:

```yaml
name: project-name          # Project identifier
version: "1.0.0"           # Project version

image:
  name: "my-image"        # Image name
  tag: "latest"             # Image tag
  registry: "ghcr.io"       # Container registry
  namespace: "myorg"        # Registry namespace

base:
  template: "ubuntu-24.04"  # Base template
  architecture:             # Target architectures
    - amd64
    - arm64
```

### Tool Configuration

Tools are organized by category:

```yaml
tools:
  languages:               # Programming languages
    go:
      version: "1.22"
      install: true
  
  security:                # Security tools
    trivy:
      install: true
  
  devops:                  # DevOps tools
    kubectl:
      version: "1.29"
      install: true
  
  packages:                # System packages
    - curl
    - git
```

## Templates

### Available Templates

| Template | Description | Best For |
|----------|-------------|----------|
| `ubuntu-24.04` | Ubuntu 24.04 LTS | General purpose, compatibility |
| `ubuntu-22.04` | Ubuntu 22.04 LTS | Long-term stability |
| `alpine-3.20` | Alpine Linux 3.20 | Minimal size, security |
| `debian-12` | Debian 12 | Stability, enterprise |

### Creating Custom Templates

1. Create a new file: `templates/base/my-template.Dockerfile`
2. Follow the multi-stage build pattern
3. Add your custom tools and configurations

Example:

```dockerfile
FROM ubuntu:24.04 AS base
# ... base setup

FROM base AS custom-tools
# ... install your tools

FROM base AS final
COPY --from=custom-tools /usr/local/bin/my-tool /usr/local/bin/
```

## Security

### Security Scanning

#### Trivy

Scans for:
- OS vulnerabilities
- Application dependencies
- Misconfigurations
- Secrets

Configuration:

```yaml
security:
  trivy:
    enabled: true
    severity: "HIGH,CRITICAL"
    exit_code: 1
```

#### CodeQL

Deep semantic code analysis for:
- Security vulnerabilities
- Code quality issues
- Best practice violations

#### SAST Tools

- **Semgrep**: Pattern-based analysis
- **Gosec**: Go-specific security
- **Bandit**: Python security

### Compliance

CIS Docker Benchmark checks:
- Container runtime security
- Image security
- Network security
- Storage security

Run compliance checks:

```bash
./scripts/compliance-check.sh <image-name>
```

## CI/CD Integration

### GitHub Actions

The included workflow provides:

1. **Validation** - Config and syntax checks
2. **Build** - Multi-arch image builds
3. **Security** - Trivy, CodeQL, SAST
4. **Compliance** - CIS benchmarks
5. **Testing** - Structure, integration, performance
6. **Signing** - Cosign keyless signing

### Environment Variables

| Variable | Description |
|----------|-------------|
| `REGISTRY` | Container registry URL |
| `IMAGE_NAME` | Full image name |
| `SLACK_WEBHOOK_URL` | Slack notifications |

### Secrets Required

- `GITHUB_TOKEN` - Provided automatically
- `SLACK_WEBHOOK_URL` - Optional, for notifications

## Troubleshooting

### Common Issues

#### Build fails with "no space left on device"

Solution: Clean up Docker cache

```bash
docker system prune -a
docker buildx prune
```

#### Multi-arch build fails

Solution: Ensure QEMU is set up

```bash
docker run --privileged --rm tonistiigi/binfmt --install all
```

#### Trivy scan takes too long

Solution: Use vulnerability database cache

```bash
export TRIVY_CACHE_DIR=/tmp/trivy-cache
```

### Debug Mode

Run CLI with verbose output:

```bash
./foundry build --verbose
```

### Logs

Check GitHub Actions logs for:
- Build output
- Test results
- Security scan findings

## Advanced Topics

### Custom Pre/Post Hooks

Add custom scripts to run before or after build:

```yaml
custom:
  pre_build: |
    echo "Pre-build tasks"
    # Custom commands
  
  post_build: |
    echo "Post-build tasks"
    # Custom commands
```

### Registry Authentication

For private registries:

```bash
# Docker login
docker login ghcr.io -u USERNAME -p TOKEN

# Or use credentials helper
echo $TOKEN | docker login ghcr.io -u USERNAME --password-stdin
```

### Image Signing

Verify signed images:

```bash
cosign verify --certificate-identity-regexp ".*" \
  --certificate-oidc-issuer-regexp ".*" \
  <image-reference>
```
