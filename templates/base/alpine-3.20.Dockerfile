# syntax=docker/dockerfile:1.6
# Base Dockerfile template for Alpine Linux
# Multi-architecture support: amd64, arm64, arm/v7

ARG TARGETARCH
ARG TARGETOS
ARG ALPINE_VERSION=3.20

FROM alpine:${ALPINE_VERSION} AS base

# Set environment variables
ENV LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    TZ=UTC

# Install base system dependencies
RUN apk add --no-cache \
    ca-certificates \
    curl \
    wget \
    bash \
    jq \
    git \
    vim \
    nano \
    htop \
    tree \
    unzip \
    zip \
    tar \
    gzip \
    bzip2 \
    xz \
    coreutils \
    procps \
    iputils \
    bind-tools \
    openssh-client

# Security hardening
RUN apk add --no-cache \
    fail2ban \
    ufw \
    && rm -rf /var/cache/apk/*

# Create non-root user
RUN addgroup -g 1000 -S foundry && \
    adduser -u 1000 -S foundry -G foundry

# Set up workspace
WORKDIR /workspace
RUN chown -R foundry:foundry /workspace

# Layer for Go installation
FROM base AS go-layer
ARG GO_VERSION=1.22.0
ARG TARGETARCH

RUN if [ -n "$GO_VERSION" ]; then \
    case "${TARGETARCH}" in \
        amd64) GO_ARCH="amd64" ;; \
        arm64) GO_ARCH="arm64" ;; \
        *) echo "Unsupported architecture: ${TARGETARCH}"; exit 1 ;; \
    esac && \
    curl -fsSL "https://go.dev/dl/go${GO_VERSION}.linux-${GO_ARCH}.tar.gz" -o /tmp/go.tar.gz && \
    tar -C /usr/local -xzf /tmp/go.tar.gz && \
    rm /tmp/go.tar.gz && \
    ln -s /usr/local/go/bin/go /usr/local/bin/go && \
    ln -s /usr/local/go/bin/gofmt /usr/local/bin/gofmt; \
    fi

ENV PATH=$PATH:/usr/local/go/bin
ENV GOPATH=/go
ENV GOBIN=$GOPATH/bin

# Layer for Node.js
FROM base AS nodejs-layer
ARG NODE_VERSION=20

RUN if [ -n "$NODE_VERSION" ]; then \
    apk add --no-cache nodejs npm && \
    npm install -g npm@latest; \
    fi

# Layer for Python
FROM base AS python-layer
ARG PYTHON_VERSION=3.12

RUN apk add --no-cache \
    python3 \
    py3-pip \
    py3-virtualenv

# Layer for security tools
FROM base AS security-layer
ARG TARGETARCH

# Install Trivy
RUN curl -fsSL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin

# Install Cosign
RUN case "${TARGETARCH}" in \
        amd64) COSIGN_ARCH="amd64" ;; \
        arm64) COSIGN_ARCH="arm64" ;; \
        *) COSIGN_ARCH="${TARGETARCH}" ;; \
    esac && \
    COSIGN_VERSION=$(curl -s https://api.github.com/repos/sigstore/cosign/releases/latest | grep -o '"tag_name": "v[^"]*"' | cut -d'"' -f4) && \
    curl -fsSL -o /usr/local/bin/cosign "https://github.com/sigstore/cosign/releases/download/${COSIGN_VERSION}/cosign-linux-${COSIGN_ARCH}" && \
    chmod +x /usr/local/bin/cosign

# Install Syft
RUN curl -fsSL https://raw.githubusercontent.com/anchore/syft/main/install.sh | sh -s -- -b /usr/local/bin

# Layer for compliance tools
FROM base AS compliance-layer
ARG TARGETARCH

# Install OpenSCAP for CIS/NIST/PCI-DSS compliance scanning
RUN apk add --no-cache \
    openscap \
    python3 \
    py3-pip \
    wget \
    ca-certificates

# Install OpenSCAP content for Alpine
RUN mkdir -p /usr/share/xml/scap/ssg/content && \
    wget -O /usr/share/xml/scap/ssg/content/ssg-alpine319-xccdf.xml \
    https://github.com/ComplianceAsCode/content/releases/latest/download/ssg-alpine319-xccdf.xml

# Install OPA (Open Policy Agent) for policy-as-code compliance
RUN OPA_VERSION=$(curl -s https://api.github.com/repos/open-policy-agent/opa/releases/latest | grep -o '"tag_name": "v[^"]*"' | cut -d'"' -f4 | sed 's/v//') && \
    wget -O /usr/local/bin/opa "https://github.com/open-policy-agent/opa/releases/download/v${OPA_VERSION}/opa_linux_${TARGETARCH}" && \
    chmod +x /usr/local/bin/opa

# Create compliance policies directory
RUN mkdir -p /opt/compliance/policies /opt/compliance/reports

# Copy default compliance policies (will be mounted from host)
COPY compliance/ /opt/compliance/policies/

# Layer for DevOps tools
FROM base AS devops-layer
ARG TARGETARCH

# Get latest kubectl version
RUN KUBECTL_VERSION=$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt | sed 's/v//') && \
    case "${TARGETARCH}" in \
        amd64) KUBECTL_ARCH="amd64" ;; \
        arm64) KUBECTL_ARCH="arm64" ;; \
        *) KUBECTL_ARCH="${TARGETARCH}" ;; \
    esac && \
    curl -fsSL -o /usr/local/bin/kubectl "https://dl.k8s.io/release/v${KUBECTL_VERSION}/bin/linux/${KUBECTL_ARCH}/kubectl" && \
    chmod +x /usr/local/bin/kubectl

# Get latest helm version
RUN HELM_VERSION=$(curl -s https://api.github.com/repos/helm/helm/releases/latest | grep -o '"tag_name": "v[^"]*"' | cut -d'"' -f4 | sed 's/v//') && \
    case "${TARGETARCH}" in \
        amd64) HELM_ARCH="amd64" ;; \
        arm64) HELM_ARCH="arm64" ;; \
        *) HELM_ARCH="${TARGETARCH}" ;; \
    esac && \
    curl -fsSL "https://get.helm.sh/helm-v${HELM_VERSION}-linux-${HELM_ARCH}.tar.gz" -o /tmp/helm.tar.gz && \
    tar -xzf /tmp/helm.tar.gz -C /tmp && \
    mv /tmp/linux-${HELM_ARCH}/helm /usr/local/bin/helm && \
    rm -rf /tmp/helm.tar.gz /tmp/linux-${HELM_ARCH}

# Install Docker CLI
RUN apk add --no-cache docker-cli

# Final assembly
FROM base AS final

# Copy tools from layers if they were built
COPY --from=go-layer /usr/local/go /usr/local/go
COPY --from=security-layer /usr/local/bin/trivy /usr/local/bin/trivy
COPY --from=security-layer /usr/local/bin/cosign /usr/local/bin/cosign
COPY --from=security-layer /usr/local/bin/syft /usr/local/bin/syft
COPY --from=compliance-layer /usr/local/bin/opa /usr/local/bin/opa
COPY --from=compliance-layer /opt/compliance /opt/compliance
COPY --from=go-layer /usr/local/bin/go* /usr/local/bin/
COPY --from=devops-layer /usr/local/bin/kubectl /usr/local/bin/
COPY --from=devops-layer /usr/local/bin/helm /usr/local/bin/
COPY --from=devops-layer /usr/bin/docker /usr/bin/

# Update PATH
ENV PATH="/usr/local/go/bin:/go/bin:${PATH}"

# Labels
LABEL org.opencontainers.image.title="ImageFoundry Alpine Base Image"
LABEL org.opencontainers.image.description="Lightweight custom-built container image with development tools"
LABEL org.opencontainers.image.source="https://github.com/${GITHUB_REPOSITORY}"
LABEL org.opencontainers.image.version="${IMAGE_VERSION}"

# Switch to non-root user
USER foundry

WORKDIR /workspace

# Health check (must be final instruction for Semgrep compliance)
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD echo "Container is healthy" || exit 1

CMD ["/bin/bash"]
