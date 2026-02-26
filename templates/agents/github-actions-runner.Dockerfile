# syntax=docker/dockerfile:1.6
# GitHub Actions Self-Hosted Runner Template
# Creates a container image that can be used as a GitHub Actions runner

ARG TARGETARCH
ARG RUNNER_VERSION=2.311.0

FROM ubuntu:24.04 AS base

ENV DEBIAN_FRONTEND=noninteractive \
    TZ=UTC \
    RUNNER_ALLOW_RUNASROOT=1

# Install dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    wget \
    git \
    jq \
    tar \
    unzip \
    apt-transport-https \
    software-properties-common \
    build-essential \
    libssl-dev \
    libffi-dev \
    python3 \
    python3-venv \
    python3-pip \
    iputils-ping \
    dnsutils \
    netcat-openbsd \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# Install Docker CLI
RUN curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list && \
    apt-get update && \
    apt-get install -y docker-ce-cli docker-buildx-plugin && \
    rm -rf /var/lib/apt/lists/*

# Install GitHub Actions runner
FROM base AS runner-install
ARG RUNNER_VERSION
ARG TARGETARCH

WORKDIR /actions-runner

RUN case "${TARGETARCH}" in \
        amd64) RUNNER_ARCH="x64" ;; \
        arm64) RUNNER_ARCH="arm64" ;; \
        *) echo "Unsupported architecture: ${TARGETARCH}"; exit 1 ;; \
    esac && \
    curl -o actions-runner-linux.tar.gz -L "https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-${RUNNER_ARCH}-${RUNNER_VERSION}.tar.gz" && \
    tar xzf ./actions-runner-linux.tar.gz && \
    rm -f actions-runner-linux.tar.gz && \
    ./bin/installdependencies.sh

# Install additional tools
FROM base AS tools-install

# Install kubectl
RUN curl -fsSL -o /usr/local/bin/kubectl "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/${TARGETARCH}/kubectl" && \
    chmod +x /usr/local/bin/kubectl

# Install Helm
RUN curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Install Node.js
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    apt-get install -y nodejs && \
    npm install -g npm@latest

# Install Trivy
RUN curl -fsSL https://aquasecurity.github.io/trivy-repo/deb/public.key | gpg --dearmor -o /usr/share/keyrings/trivy.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/trivy.gpg] https://aquasecurity.github.io/trivy-repo/deb generic main" > /etc/apt/sources.list.d/trivy.list && \
    apt-get update && apt-get install -y trivy && rm -rf /var/lib/apt/lists/*

# Final image
FROM base AS final

# Copy runner files
COPY --from=runner-install /actions-runner /actions-runner

# Copy tools
COPY --from=tools-install /usr/local/bin/kubectl /usr/local/bin/
COPY --from=tools-install /usr/local/bin/helm /usr/local/bin/
COPY --from=tools-install /usr/bin/trivy /usr/bin/
COPY --from=tools-install /usr/bin/node /usr/bin/
COPY --from=tools-install /usr/bin/npm /usr/bin/

WORKDIR /actions-runner

# Create runner user
RUN useradd -m runner && \
    chown -R runner:runner /actions-runner

# Copy startup script
COPY <<'EOF' /start.sh
#!/bin/bash
set -e

export RUNNER_ALLOW_RUNASROOT=1

# Cleanup function
cleanup() {
    echo "Cleaning up runner..."
    ./config.sh remove --unattended --token "${GITHUB_TOKEN}" || true
}
trap cleanup EXIT

# Configure runner
echo "Configuring GitHub Actions runner..."
./config.sh \
    --url "https://github.com/${GITHUB_REPOSITORY}" \
    --token "${GITHUB_TOKEN}" \
    --name "${RUNNER_NAME:-docker-runner}" \
    --work "${RUNNER_WORKDIR:-_work}" \
    --unattended \
    --replace

# Run the runner
echo "Starting runner..."
./run.sh
EOF

RUN chmod +x /start.sh

# Set proper permissions
RUN chown -R runner:runner /actions-runner

# Switch to runner user (optional - can run as root with RUNNER_ALLOW_RUNASROOT)
USER runner

ENTRYPOINT ["/start.sh"]

LABEL org.opencontainers.image.title="GitHub Actions Runner"
LABEL org.opencontainers.image.description="Self-hosted GitHub Actions runner in a container"
