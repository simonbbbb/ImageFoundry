[![E2E Pipeline](https://github.com/simonbbbb/ImageFoundry/actions/workflows/e2e-pipeline.yml/badge.svg)](https://github.com/simonbbbb/ImageFoundry/actions/workflows/e2e-pipeline.yml)
[![PR Check](https://github.com/simonbbbb/ImageFoundry/actions/workflows/pr-check.yml/badge.svg)](https://github.com/simonbbbb/ImageFoundry/actions/workflows/pr-check.yml)
[![Release](https://img.shields.io/github/v/release/simonbbbb/ImageFoundry?style=flat-square)](https://github.com/simonbbbb/ImageFoundry/releases)
[![License](https://img.shields.io/github/license/simonbbbb/ImageFoundry?style=flat-square)](LICENSE)
[![OPA](https://img.shields.io/badge/opa-policies-purple?style=flat-square)](compliance/)
[![Go Version](https://img.shields.io/github/go-mod/go-version/simonbbbb/ImageFoundry?style=flat-square)](go.mod)
[![Docker](https://img.shields.io/badge/multi--arch-amd64%20%7C%20arm64-blue?style=flat-square)](https://github.com/simonbbbb/ImageFoundry/pkgs/container/imagefoundry)

---

**Type `foundry build`** — you get a compliant, multi-arch container image with security scanning, OPA policy enforcement, and a full CI/CD pipeline.

- **OPA-governed**: Rego policies enforce CIS Docker Benchmark, NIST, and OCI standards
- **Multi-architecture**: amd64, arm64, arm/v7 from a single YAML config
- **Security built in**: Trivy, CodeQL, SAST, SBOM, and Cosign signing
- **Template driven**: Declarative tool layers for Go, Node.js, Python, kubectl, Helm, and more
- **Pipeline ready**: GitHub Actions workflows with selective builds and parallel matrices

---

## Install

| Platform | Command |
|----------|---------|
| **Go** | `go install github.com/simonbbbb/imagefoundry/cmd/foundry@latest` |
| **Docker** | `docker pull ghcr.io/simonbbbb/imagefoundry:latest` |
| **Source** | `git clone https://github.com/simonbbbb/imagefoundry.git && make build` |

> Note: The CLI (`foundry`) requires Go 1.22+. Docker builds require Docker Buildx.

---

## Quick start

```bash
# Initialize a new project
foundry init

# Edit your configuration
vim image-foundry.yaml

# Validate and build
foundry validate
foundry build

# Run security and compliance scans
foundry scan

# Run tests
foundry test
```

That's it. Four commands from nothing to a scanned, compliant image.

---

## What you get

| Artifact | Description |
|----------|-------------|
| `image-foundry.yaml` | Declarative image configuration |
| `templates/base/*.Dockerfile` | Generated multi-stage Dockerfiles |
| GHCR image `ghcr.io/simonbbbb/imagefoundry` | Built, signed, and attested |
| SBOM (SPDX / CycloneDX) | Software Bill of Materials |
| Trivy SARIF report | Vulnerability scan results |
| OPA compliance report | Policy evaluation results |

---

## Compliance

ImageFoundry embeds **OPA (Open Policy Agent)** and evaluates Rego policies at both build and scan time.

```
Write Rego policies → Build image with OPA → Evaluate at scan time → Pass or fail
```

### Active policies

| Policy | Standard | Rule |
|--------|----------|------|
| Non-root user | CIS 4.1 | Container must not run as root |
| HEALTHCHECK | CIS 4.6 | HEALTHCHECK instruction required |
| No privileged mode | CIS | Container must not run privileged |
| No dangerous capabilities | CIS | SYS_ADMIN, NET_ADMIN, etc. blocked |
| Read-only rootfs | NIST | Root filesystem should be read-only |
| Required OCI labels | OCI | title, description, version, source required |
| No `latest` tag | NIST | Production images must pin a version |
| No secrets in env | NIST | Passwords, tokens, keys not allowed |

Rego policies live in [`compliance/`](compliance/) and are built directly into the image.

---

## Features

### Architecture

| Feature | Support |
|---------|---------|
| amd64 | ✅ |
| arm64 | ✅ |
| arm/v7 | ✅ (Alpine only) |
| Multi-arch manifest | ✅ (Docker Buildx) |

### Languages & runtimes

| Tool | Default version | Config path |
|------|----------------|-------------|
| Go | 1.26 | `tools.languages.go.version` |
| Node.js | 24 | `tools.languages.nodejs.version` |
| Python | 3.14 | `tools.languages.python.version` |

### Security

| Tool | Purpose | In image |
|------|---------|----------|
| Trivy | Vulnerability scanner | ✅ |
| Cosign | Container signing | ✅ |
| Syft | SBOM generation | ✅ |
| OPA | Policy evaluation | ✅ |

### DevOps

| Tool | Default version | In image |
|------|----------------|----------|
| kubectl | 1.35 | ✅ |
| Helm | 3.19 | ✅ |
| Docker CLI | latest | ✅ |

---

## Configuration

Minimal `image-foundry.yaml`:

```yaml
name: my-project
version: "1.0.0"

image:
  name: "my-image"
  tag: "latest"
  registry: "ghcr.io"
  namespace: "myorg"

base:
  template: "ubuntu-24.04"
  architecture:
    - amd64
    - arm64

tools:
  languages:
    go:
      version: "1.26"
      install: true
  security:
    trivy:
      install: true
  packages:
    - curl
    - git

security:
  trivy:
    enabled: true
    severity: "HIGH,CRITICAL"
  compliance:
    enabled: true
    standards:
      - "cis-docker"
```

See [`configs/image-foundry.yaml`](configs/image-foundry.yaml) for the full reference.

---

## CI/CD

ImageFoundry ships with ready-to-use GitHub Actions workflows:

| Workflow | Trigger | Purpose |
|----------|---------|---------|
| `e2e-pipeline.yml` | Push / PR / tag | Full build, scan, sign, attest |
| `quick-build.yml` | Push / PR | Lightweight build (1 parallel, amd64) |
| `pr-check.yml` | PR | Validate, lint, smoke test |
| `nightly-security.yml` | Schedule (weekly) | Full vulnerability rescan |
| `regenerate-dockerfiles.yml` | Config change | Auto-update generated Dockerfiles |
| `version-check.yml` | Schedule (weekly) | Check for tool version updates |

The pipeline uses **selective builds** — only images affected by changed files are rebuilt, saving CI resources. See [`scripts/build-selective.py`](scripts/build-selective.py).

---

## CLI reference

| Command | Description |
|---------|-------------|
| `foundry init` | Initialize a new project |
| `foundry validate` | Validate configuration and templates |
| `foundry build` | Build images for all configured architectures |
| `foundry test` | Run structure, integration, and performance tests |
| `foundry scan` | Run Trivy, OPA compliance, and SAST scans |
| `foundry version` | Print version |

---

## Project structure

```
imagefoundry/
├── compliance/              # OPA Rego policies
│   ├── compliance_utils.rego
│   ├── container_security.rego
│   └── image_metadata.rego
├── cmd/foundry/             # CLI source
├── configs/                 # Reference configuration
├── docs/                    # Documentation & landing page
├── scripts/                 # Build & CI helper scripts
├── templates/               # Dockerfile templates
│   ├── base/               # OS base images
│   └── agents/             # CI/CD agent runners
├── tests/                   # Container structure tests
└── .github/workflows/       # CI/CD pipelines
```

---

## Documentation

- [Dockerfile templating](docs/dockerfile-templating.md) — Template system reference
- [Usage guide](docs/usage.md) — Extended documentation
- [Resource optimization](docs/resource-optimization.md) — CI cost optimization

---

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

See the [issue templates](.github/ISSUE_TEMPLATE/) for bug reports and feature requests.

---

## License

MIT — see [LICENSE](LICENSE).

Built with 🔨 by [Simon Balazs](https://github.com/simonbbbb).
