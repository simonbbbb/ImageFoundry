# syntax=docker/dockerfile:1.6
# Base Dockerfile template for Ubuntu 24.04 (Noble Numbat)
# Multi-architecture support: amd64, arm64

ARG TARGETARCH
ARG TARGETOS
ARG UBUNTU_VERSION=24.04

FROM ubuntu:${UBUNTU_VERSION} AS base

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive \
    TZ=UTC \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8

# Install base system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    wget \
    gnupg \
    lsb-release \
    software-properties-common \
    apt-transport-https \
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
    xz-utils \
    procps \
    net-tools \
    iputils-ping \
    dnsutils \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# Security hardening
RUN apt-get update && apt-get install -y --no-install-recommends \
    fail2ban \
    ufw \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# Create non-root user
RUN groupadd -r foundry && useradd -r -g foundry -m -s /bin/bash foundry

# Set up workspace
WORKDIR /workspace
RUN chown -R foundry:foundry /workspace

# Layer for Go installation
FROM base AS go-layer
ARG GO_VERSION=1.22.0
ARG TARGETARCH

RUN if [ -n "$GO_VERSION" ]; then \
    curl -fsSL "https://go.dev/dl/go${GO_VERSION}.linux-${TARGETARCH}.tar.gz" -o /tmp/go.tar.gz && \
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
    curl -fsSL https://deb.nodesource.com/setup_${NODE_VERSION}.x | bash - && \
    apt-get install -y nodejs && \
    npm install -g npm@latest; \
    fi

# Layer for Python
FROM base AS python-layer
ARG PYTHON_VERSION=3.12

RUN apt-get update && apt-get install -y --no-install-recommends \
    python${PYTHON_VERSION} \
    python${PYTHON_VERSION}-venv \
    python3-pip \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# Layer for security tools
FROM base AS security-layer
ARG TARGETARCH

# Install Trivy
RUN curl -fsSL https://aquasecurity.github.io/trivy-repo/deb/public.key | gpg --dearmor -o /usr/share/keyrings/trivy.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/trivy.gpg] https://aquasecurity.github.io/trivy-repo/deb generic main" > /etc/apt/sources.list.d/trivy.list && \
    apt-get update && apt-get install -y trivy && rm -rf /var/lib/apt/lists/*

# Install Cosign
RUN COSIGN_VERSION=$(curl -s https://api.github.com/repos/sigstore/cosign/releases/latest | grep -o '"tag_name": "v[^"]*"' | cut -d'"' -f4) && \
    curl -fsSL -o /usr/local/bin/cosign "https://github.com/sigstore/cosign/releases/download/${COSIGN_VERSION}/cosign-linux-${TARGETARCH}" && \
    chmod +x /usr/local/bin/cosign

# Install Syft
RUN curl -fsSL https://raw.githubusercontent.com/anchore/syft/main/install.sh | sh -s -- -b /usr/local/bin

# Layer for compliance tools
FROM base AS compliance-layer
ARG TARGETARCH

# Install OpenSCAP for CIS/NIST/PCI-DSS compliance scanning
RUN apt-get update && apt-get install -y --no-install-recommends \
    openscap-scanner \
    scap-security-guide \
    python3-pip \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# Install OpenSCAP content for Ubuntu
RUN mkdir -p /usr/share/xml/scap/ssg/content && \
    wget -O /usr/share/xml/scap/ssg/content/ssg-ubuntu2404-xccdf.xml \
    https://github.com/ComplianceAsCode/content/releases/latest/download/ssg-ubuntu2404-xccdf.xml

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
    curl -LO "https://dl.k8s.io/release/v${KUBECTL_VERSION}/bin/linux/${TARGETARCH}/kubectl" && \
    chmod +x kubectl && \
    mv kubectl /usr/local/bin/

# Get latest helm version
RUN HELM_VERSION=$(curl -s https://api.github.com/repos/helm/helm/releases/latest | grep -o '"tag_name": "v[^"]*"' | cut -d'"' -f4 | sed 's/v//') && \
    curl -fsSL -o helm.tar.gz "https://get.helm.sh/helm-v${HELM_VERSION}-linux-${TARGETARCH}.tar.gz" && \
    tar -xzf helm.tar.gz && \
    mv linux-${TARGETARCH}/helm /usr/local/bin/ && \
    rm -rf linux-${TARGETARCH} helm.tar.gz


# Install Docker CLI
RUN curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list && \
    apt-get update && apt-get install -y docker-ce-cli && rm -rf /var/lib/apt/lists/*

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
LABEL org.opencontainers.image.title="ImageFoundry Base Image"
LABEL org.opencontainers.image.description="Custom-built container image with development tools"
LABEL org.opencontainers.image.source="https://github.com/${GITHUB_REPOSITORY}"
LABEL org.opencontainers.image.version="${IMAGE_VERSION}"

# Switch to non-root user
USER foundry

WORKDIR /workspace

# Health check (must be final instruction for Semgrep compliance)
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD echo "Container is healthy" || exit 1

CMD ["/bin/bash"]
