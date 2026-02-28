# Dockerfile Templating System

This project uses a templating system to generate Dockerfiles from a central configuration file, ensuring consistency and reducing duplication.

## Overview

The templating system consists of:

- **Template**: `templates/dockerfile-template.tmpl` - A Go-template-style Dockerfile with conditional blocks
- **Configuration**: `configs/image-foundry.yaml` - Central configuration for versions and installation flags
- **Generator**: `scripts/generate-dockerfiles.py` - Python script that processes templates and generates Dockerfiles
- **Workflow**: `.github/workflows/regenerate-dockerfiles.yml` - Automated regeneration on config changes

## How It Works

1. The Python script reads the configuration from `configs/image-foundry.yaml`
2. It processes the template using the configuration values
3. It handles conditional blocks based on installation flags and base OS
4. It generates final Dockerfiles in `templates/base/`

## Configuration Structure

```yaml
tools:
  languages:
    go:
      version: "1.26.0"
      install: true
    nodejs:
      version: "24"
      install: false
    python:
      version: "3.14.3"
      install: false
  
  security:
    trivy:
      install: true
      version: "latest"
    cosign:
      install: true
      version: "latest"
    syft:
      install: true
      version: "latest"
  
  devops:
    docker:
      install: true
    kubectl:
      version: "1.35.1"
      install: true
    helm:
      version: "3.19.5"
      install: true
    terraform:
      version: "1.14.6"
      install: false
  
  packages:
    - curl
    - wget
    - jq
    - git
    - vim
    - htop

compliance:
  enabled: true
  standards:
    - cis-docker
    - nist-800-53
    - pci-dss
```

## Template Syntax

The template uses Go-template syntax with custom processing:

### Variables
```dockerfile
ARG GO_VERSION={{ .GoVersion }}
```

### Conditional Blocks
```dockerfile
{{- if .InstallNodeJS }}
# Node.js installation
FROM base AS nodejs-layer
ARG NODE_VERSION={{ .NodeVersion }}
...
{{- end }}
```

### Base OS Conditionals
```dockerfile
{{- if eq .Base "ubuntu-24.04" "ubuntu-22.04" }}
# Ubuntu-specific setup
RUN apt-get update && apt-get install -y ...
{{- end }}

{{- if eq .Base "alpine-3.20" }}
# Alpine-specific setup
RUN apk add --no-cache ...
{{- end }}
```

### Package Loops
```dockerfile
{{- range .AdditionalPackages }}
RUN apt-get update && apt-get install -y {{ . }} && rm -rf /var/lib/apt/lists/*
{{- end }}
```

## Usage

### Manual Generation

Generate all Dockerfiles:
```bash
python3 scripts/generate-dockerfiles.py
```

Generate specific base:
```bash
python3 scripts/generate-dockerfiles.py ubuntu-24.04
```

### Automated Generation

The workflow automatically regenerates Dockerfiles when:
- `configs/image-foundry.yaml` changes
- `templates/dockerfile-template.tmpl` changes
- `scripts/generate-dockerfiles.py` changes

It creates a pull request with the generated changes.

## Adding New Tools

1. Add tool configuration to `configs/image-foundry.yaml`
2. Add conditional blocks to the template
3. Regenerate Dockerfiles

Example:
```yaml
tools:
  new_tool:
    version: "1.0.0"
    install: true
```

```dockerfile
{{- if .InstallNewTool }}
# New tool installation
FROM base AS new-tool-layer
ARG NEW_TOOL_VERSION={{ .NewToolVersion }}
RUN curl -fsSL ... && install
{{- end }}
```

## Adding New Base Images

1. Add base image mapping in `scripts/generate-dockerfiles.py`
2. Add conditional blocks to the template
3. Regenerate Dockerfiles

## Benefits

- **Single Source of Truth**: All versions and flags in one config file
- **Consistency**: All Dockerfiles follow the same structure
- **Conditional Installation**: Only install what's needed, reducing attack surface
- **Easy Updates**: Change versions in one place and regenerate
- **Validation**: Automated validation of generated Dockerfiles
- **Compliance**: Built-in compliance tools and policies

## Security Considerations

- Only install tools when `install: true` is set
- Use specific versions instead of `latest` where possible
- Compliance tools are included when compliance is enabled
- Non-root user is created by default
- Multi-stage builds reduce final image size

## Troubleshooting

### Generation Fails
- Check Python dependencies: `pip install pyyaml`
- Validate config syntax: `python3 -c "import yaml; yaml.safe_load(open('configs/image-foundry.yaml'))"`
- Check template syntax

### Dockerfile Issues
- Run validation: `python3 scripts/generate-dockerfiles.py`
- Check for missing conditional blocks
- Verify base image mapping

### Workflow Issues
- Check workflow permissions
- Verify GitHub token has write access
- Check Python installation in runner
