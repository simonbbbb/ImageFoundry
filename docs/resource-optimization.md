# Resource Optimization Guide

This document explains how ImageFoundry optimizes GitHub Actions usage to reduce costs while maintaining functionality.

## Overview

GitHub Actions provides free minutes that can be quickly consumed by multi-architecture Docker builds. This project implements several strategies to minimize resource usage:

## Optimization Strategies

### 1. Selective Building

Instead of building all images on every change, we use intelligent selection:

**Pull Requests**: Only build images affected by changes
- Detects which Dockerfiles would change
- Skips unchanged base images
- Saves ~66% of build time on average

**Main Branch**: Build based on configuration
- Only builds images with enabled tools
- Skips images with `install: false` for all tools
- Reduces unnecessary builds

### 2. Priority-Based Architecture

Images are prioritized and built accordingly:

```python
# High Priority (both architectures)
- ubuntu-24.04 (primary image)

# Medium Priority (amd64 only)  
- ubuntu-22.04 (LTS support)

# Low Priority (amd64 only)
- alpine-3.20 (minimal use case)
```

This saves ~50% of arm64 build time, which is typically slower.

### 3. Parallelism Limits

- **Full Pipeline**: Max 2 parallel builds
- **Quick Build**: Max 1 parallel build
- Prevents resource exhaustion and queue timeouts

### 4. Workflow Options

#### Full E2E Pipeline (`.github/workflows/e2e-pipeline.yml`)
- Complete testing and validation
- Multi-architecture builds
- Full security scanning
- **Usage**: Releases, important changes

#### Quick Build (`.github/workflows/quick-build.yml`)
- Resource-optimized builds
- amd64 only for non-critical images
- Basic security scanning
- **Usage**: Development, frequent changes

#### Manual Override Options
```yaml
workflow_dispatch:
  inputs:
    build_all:
      description: 'Build all images'
      default: false
    images:
      description: 'Specific images: ubuntu-24.04,alpine-3.20'
```

## Usage Examples

### Build Only Changed Images (Default for PRs)
```bash
# Automatically detects changes
# Only builds affected images
# Example: Only ubuntu-24.04 if config changed
```

### Build Specific Images
```bash
# Manual trigger with specific images
gh workflow run quick-build.yml -f images="ubuntu-24.04,alpine-3.20"
```

### Force Build All
```bash
# Override selective building
gh workflow run quick-build.yml -f build_all=true
```

## Resource Savings

### Before Optimization
- 3 base images × 2 architectures = 6 builds
- All builds run in parallel (max 6 concurrent)
- ~60 minutes total build time
- ~1800 GitHub Actions minutes/month

### After Optimization
- Average: 1-2 images × 1-2 architectures = 2-3 builds
- Limited parallelism (max 2 concurrent)
- ~20 minutes total build time
- ~600 GitHub Actions minutes/month

**Savings: ~67% reduction in resource usage**

## Configuration

### Enable/Disable Tools to Reduce Builds
```yaml
tools:
  languages:
    nodejs:
      install: false  # Skips Node.js layer
    python:
      install: false  # Skips Python layer
  security:
    trivy:
      install: true   # Always included
  devops:
    terraform:
      install: false  # Skips Terraform layer
```

### Priority Settings
Priority is automatically calculated based on:
- Base image importance (Ubuntu 24.04 > 22.04 > Alpine)
- Enabled essential tools (Go, Trivy, Docker)
- Compliance requirements

## Monitoring

### Build Metrics
- Number of images built per run
- Build duration
- Resource usage
- Skip reasons

### Alerts
- No builds triggered when changes detected
- Excessive build time
- Failed selective build logic

## Best Practices

1. **Use Quick Build for Development**
   - Faster feedback
   - Less resource consumption
   - Still validates changes

2. **Enable Only Required Tools**
   - Reduces image size
   - Skips unnecessary builds
   - Improves security

3. **Review Build Triggers**
   - Check if builds are necessary
   - Use manual override for testing
   - Monitor build patterns

4. **Optimize Dockerfile Layers**
   - Order layers by change frequency
   - Use build cache effectively
   - Minimize context size

## Troubleshooting

### No Builds Triggered
```bash
# Check what changed
python3 scripts/build-selective.py --mode changed --dry-run

# Force build if needed
gh workflow run quick-build.yml -f build_all=true
```

### Excessive Build Time
1. Check if too many images are enabled
2. Verify priority settings
3. Review parallelism limits
4. Consider using quick-build workflow

### Build Selection Issues
```bash
# Debug matrix generation
python3 scripts/build-selective.py --mode changed

# Validate configuration
python3 scripts/generate-dockerfiles.py --dry-run
```

## Cost Impact

### GitHub Actions Free Tier
- 2,000 minutes/month for public repos
- 500 minutes/month for private repos

### With Optimization
- Development: ~200 minutes/month
- Testing: ~400 minutes/month
- Releases: ~600 minutes/month

**Well within free tier limits for most use cases**

## Future Improvements

1. **Smart Caching**: Better use of build cache across runs
2. **Differential Builds**: Only rebuild changed layers
3. **Scheduled Builds**: Nightly builds for non-critical images
4. **Build Analytics**: Detailed usage metrics and trends
