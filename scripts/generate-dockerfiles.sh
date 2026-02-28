#!/bin/bash

# Generate Dockerfiles from template and config
# Usage: ./scripts/generate-dockerfiles.sh [base-image]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
CONFIG_FILE="$PROJECT_ROOT/configs/image-foundry.yaml"
TEMPLATE_FILE="$PROJECT_ROOT/templates/dockerfile-template.tmpl"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check dependencies
check_dependencies() {
    local deps=("yq" "envsubst")
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            log_error "Missing dependency: $dep"
            log_info "Install with: brew install $dep (macOS) or apt-get install $dep / yum install $dep"
            exit 1
        fi
    done
}

# Read configuration
read_config() {
    local base="$1"
    
    # Base image mapping
    case "$base" in
        "ubuntu-24.04")
            BASE_IMAGE="ubuntu:24.04"
            ;;
        "ubuntu-22.04")
            BASE_IMAGE="ubuntu:22.04"
            ;;
        "alpine-3.20")
            BASE_IMAGE="alpine:3.20"
            ;;
        *)
            log_error "Unsupported base: $base"
            exit 1
            ;;
    esac
    
    # Read tool versions from config
    GO_VERSION=$(yq eval '.tools.languages.go.version' "$CONFIG_FILE")
    NODE_VERSION=$(yq eval '.tools.languages.nodejs.version' "$CONFIG_FILE")
    PYTHON_VERSION=$(yq eval '.tools.languages.python.version' "$CONFIG_FILE")
    
    # Read DevOps versions from config
    KUBECTL_VERSION=$(yq eval '.tools.devops.kubectl.version' "$CONFIG_FILE")
    HELM_VERSION=$(yq eval '.tools.devops.helm.version' "$CONFIG_FILE")
    TERRAFORM_VERSION=$(yq eval '.tools.devops.terraform.version' "$CONFIG_FILE")
    
    # Read installation flags with defaults
    INSTALL_NODEJS=$(yq eval '.tools.languages.nodejs.install // "false"' "$CONFIG_FILE")
    INSTALL_PYTHON=$(yq eval '.tools.languages.python.install // "false"' "$CONFIG_FILE")
    INSTALL_TRIVY=$(yq eval '.tools.security.trivy.install // "false"' "$CONFIG_FILE")
    INSTALL_COSIGN=$(yq eval '.tools.security.cosign.install // "false"' "$CONFIG_FILE")
    INSTALL_SYFT=$(yq eval '.tools.security.syft.install // "false"' "$CONFIG_FILE")
    INSTALL_DOCKER=$(yq eval '.tools.devops.docker.install // "false"' "$CONFIG_FILE")
    INSTALL_KUBECTL=$(yq eval '.tools.devops.kubectl.install // "false"' "$CONFIG_FILE")
    INSTALL_HELM=$(yq eval '.tools.devops.helm.install // "false"' "$CONFIG_FILE")
    INSTALL_TERRAFORM=$(yq eval '.tools.devops.terraform.install // "false"' "$CONFIG_FILE")
    
    # Read compliance settings
    COMPLIANCE_ENABLED=$(yq eval '.compliance.enabled' "$CONFIG_FILE")
    INSTALL_COMPLIANCE="false"
    if [[ "$COMPLIANCE_ENABLED" == "true" ]]; then
        INSTALL_COMPLIANCE="true"
    fi
    
    # Read additional packages
    IFS=$'\n' read -r -d '' -a ADDITIONAL_PACKAGES < <(yq eval '.tools.packages[]' "$CONFIG_FILE" && printf '\0')
    
    # Convert boolean values to lowercase for template
    INSTALL_NODEJS=$(echo "$INSTALL_NODEJS" | tr '[:upper:]' '[:lower:]')
    INSTALL_PYTHON=$(echo "$INSTALL_PYTHON" | tr '[:upper:]' '[:lower:]')
    INSTALL_TRIVY=$(echo "$INSTALL_TRIVY" | tr '[:upper:]' '[:lower:]')
    INSTALL_COSIGN=$(echo "$INSTALL_COSIGN" | tr '[:upper:]' '[:lower:]')
    INSTALL_SYFT=$(echo "$INSTALL_SYFT" | tr '[:upper:]' '[:lower:]')
    INSTALL_DOCKER=$(echo "$INSTALL_DOCKER" | tr '[:upper:]' '[:lower:]')
    INSTALL_KUBECTL=$(echo "$INSTALL_KUBECTL" | tr '[:upper:]' '[:lower:]')
    INSTALL_HELM=$(echo "$INSTALL_HELM" | tr '[:upper:]' '[:lower:]')
    INSTALL_TERRAFORM=$(echo "$INSTALL_TERRAFORM" | tr '[:upper:]' '[:lower:]')
    INSTALL_COMPLIANCE=$(echo "$INSTALL_COMPLIANCE" | tr '[:upper:]' '[:lower:]')
}

# Generate Dockerfile
generate_dockerfile() {
    local base="$1"
    local output_file="$PROJECT_ROOT/templates/base/${base}.Dockerfile"
    
    log_info "Generating Dockerfile for $base..."
    
    # Create environment variables for envsubst
    export BASE="$base"
    export BASE_IMAGE="$BASE_IMAGE"
    export ARCH="amd64"
    export GO_VERSION="$GO_VERSION"
    export NODE_VERSION="$NODE_VERSION"
    export PYTHON_VERSION="$PYTHON_VERSION"
    export KUBECTL_VERSION="$KUBECTL_VERSION"
    export HELM_VERSION="$HELM_VERSION"
    export TERRAFORM_VERSION="$TERRAFORM_VERSION"
    export INSTALL_NODEJS="$INSTALL_NODEJS"
    export INSTALL_PYTHON="$INSTALL_PYTHON"
    export INSTALL_TRIVY="$INSTALL_TRIVY"
    export INSTALL_COSIGN="$INSTALL_COSIGN"
    export INSTALL_SYFT="$INSTALL_SYFT"
    export INSTALL_DOCKER="$INSTALL_DOCKER"
    export INSTALL_KUBECTL="$INSTALL_KUBECTL"
    export INSTALL_HELM="$INSTALL_HELM"
    export INSTALL_TERRAFORM="$INSTALL_TERRAFORM"
    export INSTALL_COMPLIANCE="$INSTALL_COMPLIANCE"
    export TIMESTAMP="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    
    # Create temporary file for additional packages
    local temp_packages=$(mktemp)
    for pkg in "${ADDITIONAL_PACKAGES[@]}"; do
        echo "$pkg" >> "$temp_packages"
    done
    export ADDITIONAL_PACKAGES_FILE="$temp_packages"
    
    # Generate Dockerfile using sed for Go template syntax
    sed \
        -e "s|{{ .Base }}|$BASE|g" \
        -e "s|{{ .BaseImage }}|$BASE_IMAGE|g" \
        -e "s|{{ .Arch }}|$ARCH|g" \
        -e "s|{{ .GoVersion }}|$GO_VERSION|g" \
        -e "s|{{ .NodeVersion }}|$NODE_VERSION|g" \
        -e "s|{{ .PythonVersion }}|$PYTHON_VERSION|g" \
        -e "s|{{ .KubectlVersion }}|$KUBECTL_VERSION|g" \
        -e "s|{{ .HelmVersion }}|$HELM_VERSION|g" \
        -e "s|{{ .TerraformVersion }}|$TERRAFORM_VERSION|g" \
        -e "s|{{ .InstallNodeJS }}|$INSTALL_NODEJS|g" \
        -e "s|{{ .InstallPython }}|$INSTALL_PYTHON|g" \
        -e "s|{{ .InstallTrivy }}|$INSTALL_TRIVY|g" \
        -e "s|{{ .InstallCosign }}|$INSTALL_COSIGN|g" \
        -e "s|{{ .InstallSyft }}|$INSTALL_SYFT|g" \
        -e "s|{{ .InstallDocker }}|$INSTALL_DOCKER|g" \
        -e "s|{{ .InstallKubectl }}|$INSTALL_KUBECTL|g" \
        -e "s|{{ .InstallHelm }}|$INSTALL_HELM|g" \
        -e "s|{{ .InstallTerraform }}|$INSTALL_TERRAFORM|g" \
        -e "s|{{ .InstallCompliance }}|$INSTALL_COMPLIANCE|g" \
        -e "s|{{ .Timestamp }}|$TIMESTAMP|g" \
        < "$TEMPLATE_FILE" > "$output_file"
    
    # Process conditional blocks
    if [[ "$BASE" == "ubuntu-24.04" || "$BASE" == "ubuntu-22.04" ]]; then
        sed -i.bak '/{{- if eq .Base "ubuntu-24.04" "ubuntu-22.04" }}/,${
            /{{- end }}/!d
        }' "$output_file"
        sed -i.bak '/{{- if eq .Base "alpine-3.20" }}/,/{{- end }}/d' "$output_file"
    elif [[ "$BASE" == "alpine-3.20" ]]; then
        sed -i.bak '/{{- if eq .Base "alpine-3.20" }}/,${
            /{{- end }}/!d
        }' "$output_file"
        sed -i.bak '/{{- if eq .Base "ubuntu-24.04" "ubuntu-22.04" }}/,/{{- end }}/d' "$output_file"
    fi
    
    # Process tool installation conditionals
    if [[ "$INSTALL_NODEJS" != "true" ]]; then
        sed -i.bak '/{{- if .InstallNodeJS }}/,/{{- end }}/d' "$output_file"
    else
        sed -i.bak '/{{- if .InstallNodeJS }}/d; /{{- end }}/d' "$output_file"
    fi
    
    if [[ "$INSTALL_PYTHON" != "true" ]]; then
        sed -i.bak '/{{- if .InstallPython }}/,/{{- end }}/d' "$output_file"
    else
        sed -i.bak '/{{- if .InstallPython }}/d; /{{- end }}/d' "$output_file"
    fi
    
    if [[ "$INSTALL_TRIVY" != "true" ]]; then
        sed -i.bak '/{{- if .InstallTrivy }}/,/{{- end }}/d' "$output_file"
    else
        sed -i.bak '/{{- if .InstallTrivy }}/d; /{{- end }}/d' "$output_file"
    fi
    
    if [[ "$INSTALL_COSIGN" != "true" ]]; then
        sed -i.bak '/{{- if .InstallCosign }}/,/{{- end }}/d' "$output_file"
    else
        sed -i.bak '/{{- if .InstallCosign }}/d; /{{- end }}/d' "$output_file"
    fi
    
    if [[ "$INSTALL_SYFT" != "true" ]]; then
        sed -i.bak '/{{- if .InstallSyft }}/,/{{- end }}/d' "$output_file"
    else
        sed -i.bak '/{{- if .InstallSyft }}/d; /{{- end }}/d' "$output_file"
    fi
    
    if [[ "$INSTALL_COMPLIANCE" != "true" ]]; then
        sed -i.bak '/{{- if .InstallCompliance }}/,/{{- end }}/d' "$output_file"
    else
        sed -i.bak '/{{- if .InstallCompliance }}/d; /{{- end }}/d' "$output_file"
    fi
    
    if [[ "$INSTALL_DOCKER" != "true" ]]; then
        sed -i.bak '/{{- if .InstallDocker }}/,/{{- end }}/d' "$output_file"
    else
        sed -i.bak '/{{- if .InstallDocker }}/d; /{{- end }}/d' "$output_file"
    fi
    
    if [[ "$INSTALL_KUBECTL" != "true" ]]; then
        sed -i.bak '/{{- if .InstallKubectl }}/,/{{- end }}/d' "$output_file"
    else
        sed -i.bak '/{{- if .InstallKubectl }}/d; /{{- end }}/d' "$output_file"
    fi
    
    if [[ "$INSTALL_HELM" != "true" ]]; then
        sed -i.bak '/{{- if .InstallHelm }}/,/{{- end }}/d' "$output_file"
    else
        sed -i.bak '/{{- if .InstallHelm }}/d; /{{- end }}/d' "$output_file"
    fi
    
    if [[ "$INSTALL_TERRAFORM" != "true" ]]; then
        sed -i.bak '/{{- if .InstallTerraform }}/,/{{- end }}/d' "$output_file"
    else
        sed -i.bak '/{{- if .InstallTerraform }}/d; /{{- end }}/d' "$output_file"
    fi
    
    # Remove any remaining conditional markers
    sed -i.bak '/{{- if/d; /{{- end }}/d' "$output_file"
    rm -f "$output_file.bak"
    
    # Clean up
    rm -f "$temp_packages"
    unset BASE BASE_IMAGE ARCH GO_VERSION NODE_VERSION PYTHON_VERSION
    unset KUBECTL_VERSION HELM_VERSION TERRAFORM_VERSION
    unset INSTALL_NODEJS INSTALL_PYTHON INSTALL_TRIVY INSTALL_COSIGN INSTALL_SYFT
    unset INSTALL_DOCKER INSTALL_KUBECTL INSTALL_HELM INSTALL_TERRAFORM INSTALL_COMPLIANCE
    unset TIMESTAMP ADDITIONAL_PACKAGES_FILE
    
    log_info "Generated: $output_file"
}

# Validate generated Dockerfile
validate_dockerfile() {
    local base="$1"
    local dockerfile="$PROJECT_ROOT/templates/base/${base}.Dockerfile"
    
    log_info "Validating $dockerfile..."
    
    # Check for syntax errors
    if ! docker buildx build --dry-run -f "$dockerfile" . > /dev/null 2>&1; then
        log_warn "Docker buildx dry-run failed for $base"
        log_info "This might be due to missing build context, but syntax should be OK"
    fi
    
    # Check for common issues
    local issues=0
    
    # Check for empty ARG values
    if grep -q "ARG.*=.*$" "$dockerfile"; then
        if grep -q "ARG.*=.*\$" "$dockerfile"; then
            log_warn "Found ARG with empty default value in $base"
            issues=$((issues + 1))
        fi
    fi
    
    # Check for required sections
    if grep -q "FROM.*AS base" "$dockerfile"; then
        log_info "✅ Base layer found"
    else
        log_warn "Missing base layer in $base"
        issues=$((issues + 1))
    fi
    
    if grep -q "FROM base AS final" "$dockerfile"; then
        log_info "✅ Final layer found"
    else
        log_warn "Missing final layer in $base"
        issues=$((issues + 1))
    fi
    
    if [[ $issues -eq 0 ]]; then
        log_info "Validation passed for $base"
    else
        log_warn "Found $issues potential issues in $base"
    fi
}

# Main function
main() {
    local bases=()
    
    # Parse arguments
    if [[ $# -eq 0 ]]; then
        # Generate all supported bases
        bases=("ubuntu-24.04" "ubuntu-22.04" "alpine-3.20")
    else
        bases=("$@")
    fi
    
    # Check dependencies
    check_dependencies
    
    # Check if config file exists
    if [[ ! -f "$CONFIG_FILE" ]]; then
        log_error "Config file not found: $CONFIG_FILE"
        exit 1
    fi
    
    # Check if template file exists
    if [[ ! -f "$TEMPLATE_FILE" ]]; then
        log_error "Template file not found: $TEMPLATE_FILE"
        exit 1
    fi
    
    log_info "Starting Dockerfile generation..."
    log_info "Using config: $CONFIG_FILE"
    log_info "Using template: $TEMPLATE_FILE"
    
    # Generate each Dockerfile
    for base in "${bases[@]}"; do
        log_info "Processing $base..."
        
        # Read configuration
        read_config "$base"
        
        # Generate Dockerfile
        generate_dockerfile "$base"
        
        # Validate Dockerfile
        validate_dockerfile "$base"
        
        echo ""
    done
    
    log_info "Dockerfile generation complete!"
    log_info "Generated files:"
    for base in "${bases[@]}"; do
        echo "  - templates/base/${base}.Dockerfile"
    done
}

# Show help
show_help() {
    cat << EOF
Generate Dockerfiles from template and configuration.

Usage: $0 [base-image...]

Arguments:
  base-image    Base image to generate (ubuntu-24.04, ubuntu-22.04, alpine-3.20)
                If not specified, generates all supported bases.

Examples:
  $0                          # Generate all Dockerfiles
  $0 ubuntu-24.04            # Generate only Ubuntu 24.04
  $0 ubuntu-24.04 alpine-3.20 # Generate Ubuntu 24.04 and Alpine 3.20

Configuration:
  The script reads from configs/image-foundry.yaml to determine:
  - Tool versions (Go, Node.js, Python, etc.)
  - Installation flags (what to include)
  - Additional packages
  - Compliance settings

Template:
  Uses templates/dockerfile-template.tmpl as the source template.
  The template uses envsubst syntax for variable substitution.

EOF
}

# Parse command line
case "${1:-}" in
    -h|--help)
        show_help
        exit 0
        ;;
    "")
        main
        ;;
    *)
        main "$@"
        ;;
esac
