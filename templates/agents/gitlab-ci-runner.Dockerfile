# syntax=docker/dockerfile:1.6
# GitLab CI Runner Template
# Creates a container image that can be used as a GitLab CI runner

ARG TARGETARCH
ARG GITLAB_RUNNER_VERSION=v16.7.0

FROM ubuntu:24.04 AS base

ENV DEBIAN_FRONTEND=noninteractive \
    TZ=UTC

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
    openssh-client \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# Install Docker CLI
RUN curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list && \
    apt-get update && \
    apt-get install -y docker-ce-cli docker-buildx-plugin && \
    rm -rf /var/lib/apt/lists/*

# Install GitLab Runner
FROM base AS runner-install
ARG GITLAB_RUNNER_VERSION
ARG TARGETARCH

RUN case "${TARGETARCH}" in \
        amd64) RUNNER_ARCH="amd64" ;; \
        arm64) RUNNER_ARCH="arm64" ;; \
        *) echo "Unsupported architecture: ${TARGETARCH}"; exit 1 ;; \
    esac && \
    curl -L -o /usr/local/bin/gitlab-runner "https://gitlab-runner-downloads.s3.amazonaws.com/${GITLAB_RUNNER_VERSION}/binaries/gitlab-runner-linux-${RUNNER_ARCH}" && \
    chmod +x /usr/local/bin/gitlab-runner

# Install additional tools
FROM base AS tools-install
ARG TARGETARCH

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

# Install GitLab CLI
RUN curl -fsSL -o /tmp/glab.tar.gz "https://gitlab.com/gitlab-org/cli/-/releases/latest/download/glab_${TARGETARCH}.Linux.tar.gz" && \
    tar -xzf /tmp/glab.tar.gz -C /tmp && \
    mv /tmp/bin/glab /usr/local/bin/glab && \
    rm -rf /tmp/glab.tar.gz /tmp/bin

# Final image
FROM base AS final

# Copy runner binary
COPY --from=runner-install /usr/local/bin/gitlab-runner /usr/local/bin/

# Copy tools
COPY --from=tools-install /usr/local/bin/kubectl /usr/local/bin/
COPY --from=tools-install /usr/local/bin/helm /usr/local/bin/
COPY --from=tools-install /usr/local/bin/glab /usr/local/bin/
COPY --from=tools-install /usr/bin/trivy /usr/bin/
COPY --from=tools-install /usr/bin/node /usr/bin/
COPY --from=tools-install /usr/bin/npm /usr/bin/

# Create gitlab-runner user
RUN useradd -m gitlab-runner && \
    mkdir -p /etc/gitlab-runner && \
    mkdir -p /home/gitlab-runner/builds

# Copy startup script
COPY <<'EOF' /start.sh
#!/bin/bash
set -e

# Get runner token from environment
RUNNER_TOKEN="${RUNNER_TOKEN:-${CI_RUNNER_TOKEN}}"
GITLAB_URL="${GITLAB_URL:-https://gitlab.com}"
RUNNER_NAME="${RUNNER_NAME:-gitlab-docker-runner}"
RUNNER_EXECUTOR="${RUNNER_EXECUTOR:-docker}"

# Configure and register runner
echo "Registering GitLab runner..."
gitlab-runner register \
    --non-interactive \
    --url "${GITLAB_URL}" \
    --token "${RUNNER_TOKEN}" \
    --executor "${RUNNER_EXECUTOR}" \
    --docker-image "docker:latest" \
    --name "${RUNNER_NAME}" \
    --tag-list "${RUNNER_TAGS:-docker,linux}" \
    --run-untagged="${RUNNER_UNTAGGED:-false}" \
    --locked="${RUNNER_LOCKED:-false}" \
    --access-level="${RUNNER_ACCESS_LEVEL:-not_protected}" \
    || true

# Start runner
echo "Starting GitLab runner..."
gitlab-runner run --user=gitlab-runner --working-directory=/home/gitlab-runner
EOF

RUN chmod +x /start.sh && \
    chown -R gitlab-runner:gitlab-runner /etc/gitlab-runner /home/gitlab-runner

USER gitlab-runner

WORKDIR /home/gitlab-runner

ENTRYPOINT ["/start.sh"]

LABEL org.opencontainers.image.title="GitLab CI Runner"
LABEL org.opencontainers.image.description="Self-hosted GitLab CI runner in a container"
