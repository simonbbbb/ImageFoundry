# ImageFoundry 🔨

A powerful, extensible container image builder with full E2E CI/CD pipeline, security scanning, compliance checks, and multi-architecture support.

[![E2E Pipeline](https://github.com/yourorg/imagefoundry/actions/workflows/e2e-pipeline.yml/badge.svg)](https://github.com/yourorg/imagefoundry/actions/workflows/e2e-pipeline.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

## Features ✨

- **Multi-Architecture Support** - Build for amd64, arm64, and more
- **Template-Based** - Pre-configured templates for Ubuntu, Alpine, and more
- **Declarative Configuration** - Simple YAML-based configuration
- **Security Scanning** - Integrated Trivy, CodeQL, SAST scanning
- **Compliance Checking** - CIS Docker Benchmark, OpenSCAP integration
- **SBOM Generation** - Automatic Software Bill of Materials
- **Image Signing** - Cosign keyless signing support
- **Performance Testing** - Built-in benchmark and optimization tools
- **Matrix CI/CD** - GitHub Actions with parallel job execution
- **Extensible** - Easy to add custom tools and templates

## Quick Start 🚀

### Installation

```bash
# Clone the repository
git clone https://github.com/simonbbbb/imagefoundry.git
cd imagefoundry

# Build the CLI tool
go build -o foundry ./cmd/foundry

# Or install directly
go install github.com/simonbbbb/imagefoundry/cmd/foundry@latest
```

### Initialize a New Project

```bash
foundry init
```

This creates a new project structure with example configuration.

### Configuration

Edit `image-foundry.yaml`:

```yaml
name: my-project
version: "1.0.0"

image:
  name: "my-custom-image"
  tag: "latest"
  registry: "ghcr.io"
  namespace: "myorg"

base:
  template: "ubuntu-24.04"  # or ubuntu-22.04, alpine-3.20
  architecture:
    - amd64
    - arm64

tools:
  languages:
    go:
      version: "1.22"
      install: true
    nodejs:
      version: "20"
      install: false
  
  security:
    trivy:
      install: true
    cosign:
      install: true
  
  devops:
    kubectl:
      version: "1.29"
      install: true
    helm:
      version: "3.14"
      install: true

security:
  trivy:
    enabled: true
    severity: "HIGH,CRITICAL"
  
  codeql:
    enabled: true
    languages:
      - go
  
  compliance:
    enabled: true
    standards:
      - "cis-docker"
```

### Build

```bash
# Validate configuration
foundry validate

# Build images
foundry build

# Run tests
foundry test

# Run security scans
foundry scan
```

## Project Structure 📁

```
imagefoundry/
├── .github/workflows/       # CI/CD workflows
├── cmd/foundry/             # CLI tool source
├── configs/                 # Example configurations
├── docs/                    # Documentation
├── examples/                # Example projects
├── scripts/                 # Helper scripts
│   ├── compliance-check.sh
│   ├── integration-test.sh
│   └── performance-test.sh
├── templates/               # Dockerfile templates
│   ├── base/               # Base OS templates
│   │   ├── ubuntu-24.04.Dockerfile
│   │   ├── ubuntu-22.04.Dockerfile
│   │   └── alpine-3.20.Dockerfile
│   └── agents/             # CI/CD agent templates
├── tests/                   # Test configurations
│   └── structure-tests.yaml
├── go.mod
├── go.sum
└── README.md
```

## Available Templates 🐳

### Base Images

| Template | OS | Size | Architectures |
|----------|-----|------|---------------|
| `ubuntu-24.04` | Ubuntu 24.04 LTS | ~200MB | amd64, arm64 |
| `ubuntu-22.04` | Ubuntu 22.04 LTS | ~180MB | amd64, arm64 |
| `alpine-3.20` | Alpine Linux 3.20 | ~50MB | amd64, arm64, arm/v7 |
| `debian-12` | Debian 12 (Bookworm) | ~150MB | amd64, arm64 |

### Pre-configured Tools

**Languages & Runtimes:**
- Go (1.22, 1.21)
- Node.js (20, 18)
- Python (3.12, 3.11, 3.10)
- Rust (latest)
- .NET (8.0, 6.0)
- Java (21, 17)

**Security Tools:**
- Trivy - Vulnerability scanner
- Cosign - Container signing
- Syft - SBOM generator
- Grype - Vulnerability scanner
- Falco - Runtime security

**DevOps Tools:**
- kubectl (1.29, 1.28)
- Helm (3.14, 3.13)
- Docker CLI
- Terraform (1.7)
- Pulumi (latest)
- ArgoCD CLI

## E2E Pipeline 🔒

The GitHub Actions workflow includes:

1. **Validation** - Config and Dockerfile syntax checks
2. **Build Matrix** - Parallel multi-arch builds
3. **Security Scanning:**
   - Trivy vulnerability scan
   - CodeQL analysis
   - SAST (Semgrep, Gosec)
4. **Compliance Checks:**
   - CIS Docker Benchmark
   - Custom security policies
5. **Testing:**
   - Container structure tests
   - Integration tests
   - Performance benchmarks
6. **Signing & Attestation:**
   - Cosign keyless signing
   - SBOM attestation
   - Provenance attestation

## Security Scanning 🛡️

### Trivy

```yaml
security:
  trivy:
    enabled: true
    severity: "CRITICAL,HIGH"
    exit_code: 1
    ignore_unfixed: false
```

### CodeQL

```yaml
security:
  codeql:
    enabled: true
    languages:
      - go
      - javascript
      - python
```

### SAST Tools

```yaml
security:
  sast:
    enabled: true
    tools:
      - semgrep
      - gosec
      - bandit
```

## Compliance Checking 📋

### CIS Docker Benchmark

The pipeline automatically checks:
- Container user configuration
- HEALTHCHECK presence
- Secret management
- File permissions
- Network policies

### Custom Policies

Add custom compliance scripts in `scripts/compliance-check.sh`.

## Performance Testing ⚡

Automated benchmarks include:
- Image pull time
- Container startup time
- Image size analysis
- Memory footprint
- Layer count optimization
- Concurrent startup performance

## Configuration Reference 📖

### Full Configuration Example

See `configs/image-foundry.yaml` for a complete example.

### Key Options

| Option | Description | Default |
|--------|-------------|---------|
| `base.template` | Base OS template | `ubuntu-24.04` |
| `base.architecture` | Target architectures | `[amd64]` |
| `optimization.multi_stage` | Enable multi-stage builds | `true` |
| `optimization.cache_layers` | Enable layer caching | `true` |
| `output.sbom.enabled` | Generate SBOM | `true` |
| `output.signing.enabled` | Sign images | `true` |

## CLI Commands 🖥️

```bash
foundry init          # Initialize new project
foundry validate      # Validate configuration
foundry build         # Build images
foundry test          # Run tests
foundry scan          # Run security scans
foundry version       # Show version
```

## CI/CD Integration 🔧

### GitHub Actions

The included workflow automatically:
- Builds multi-arch images
- Runs security scans
- Performs compliance checks
- Generates SBOMs
- Signs images with Cosign

### GitLab CI

Example `.gitlab-ci.yml` included in examples.

### Jenkins

Pipeline script available in examples.

## Customization 🔨

### Adding Custom Tools

1. Create a new layer in the Dockerfile template
2. Add tool configuration to YAML schema
3. Update CLI to handle the tool

### Creating Custom Templates

```dockerfile
# templates/base/my-custom.Dockerfile
FROM ubuntu:24.04

# Your custom setup
COPY --from=security-layer /usr/local/bin/trivy /usr/local/bin/
```

### Pre/Post Build Hooks

```yaml
custom:
  pre_build: |
    echo "Running pre-build tasks..."
    # Your custom logic
  
  post_build: |
    echo "Running post-build tasks..."
    # Your custom logic
```

## Examples 📚

See `examples/` directory for:
- CI/CD agent images
- Development environment images
- Production-ready base images
- Custom tool configurations

## Contributing 🤝

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License 📄

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments 🙏

- [Trivy](https://github.com/aquasecurity/trivy) - Security scanner
- [Cosign](https://github.com/sigstore/cosign) - Container signing
- [Syft](https://github.com/anchore/syft) - SBOM generator
- [Docker Buildx](https://github.com/docker/buildx) - Multi-arch builds

## Roadmap 🗺️

- [ ] Windows container support
- [ ] Additional base images (RHEL, SLES)
- [ ] Web UI for configuration
- [ ] Integration with container registries (ECR, ACR, GCR)
- [ ] Automated update notifications
- [ ] Image diff visualization
