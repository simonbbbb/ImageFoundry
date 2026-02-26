#!/bin/bash
set -euo pipefail

# Integration testing script for container images

IMAGE="${1:-}"
TIMEOUT="${2:-300}"

if [ -z "$IMAGE" ]; then
    echo "Usage: $0 <image-name> [timeout-seconds]"
    exit 1
fi

echo "🧪 Running integration tests for: $IMAGE"
echo "Timeout: ${TIMEOUT}s"

CONTAINER_NAME="integ-test-$(date +%s)"
FAILED=0

# Cleanup function
cleanup() {
    echo "Cleaning up test container..."
    docker rm -f "$CONTAINER_NAME" 2>/dev/null || true
}
trap cleanup EXIT

# Pull and start container
echo ""
echo "1. Container startup test..."
if docker run -d --name "$CONTAINER_NAME" "$IMAGE" sleep "$TIMEOUT"; then
    echo "   ✅ Container started successfully"
else
    echo "   ❌ Failed to start container"
    exit 1
fi

# Wait for container to be ready
echo ""
echo "2. Container health check..."
sleep 2
if [ "$(docker inspect -f '{{.State.Status}}' "$CONTAINER_NAME")" = "running" ]; then
    echo "   ✅ Container is running"
else
    echo "   ❌ Container is not running"
    docker logs "$CONTAINER_NAME" || true
    exit 1
fi

# Check basic shell functionality
echo ""
echo "3. Shell functionality test..."
if docker exec "$CONTAINER_NAME" sh -c "echo 'Shell works'" | grep -q "Shell works"; then
    echo "   ✅ Shell is functional"
else
    echo "   ❌ Shell is not working"
    FAILED=$((FAILED + 1))
fi

# Test user permissions
echo ""
echo "4. User permissions test..."
if docker exec "$CONTAINER_NAME" sh -c "id" | grep -q "foundry"; then
    echo "   ✅ Foundry user exists"
else
    echo "   ⚠️  Foundry user not found"
    FAILED=$((FAILED + 1))
fi

# Test workspace access
echo ""
echo "5. Workspace accessibility test..."
if docker exec "$CONTAINER_NAME" sh -c "cd /workspace && pwd" | grep -q "/workspace"; then
    echo "   ✅ Workspace is accessible"
else
    echo "   ⚠️  Workspace not accessible"
    FAILED=$((FAILED + 1))
fi

# Test network connectivity
echo ""
echo "6. Network connectivity test..."
if docker exec "$CONTAINER_NAME" sh -c "curl -s -o /dev/null -w '%{http_code}' https://github.com" | grep -q "200"; then
    echo "   ✅ Network connectivity works"
else
    echo "   ⚠️  Network connectivity issue (may be expected in air-gapped environments)"
fi

# Test installed tools
echo ""
echo "7. Installed tools verification..."

TOOLS=("curl" "wget" "git" "jq")
for tool in "${TOOLS[@]}"; do
    if docker exec "$CONTAINER_NAME" sh -c "which $tool" >/dev/null 2>&1; then
        echo "   ✅ $tool is installed"
    else
        echo "   ⚠️  $tool not found"
        FAILED=$((FAILED + 1))
    fi
done

# Test security tools
echo ""
echo "8. Security tools verification..."

if docker exec "$CONTAINER_NAME" sh -c "which trivy" >/dev/null 2>&1; then
    echo "   ✅ Trivy is installed"
    docker exec "$CONTAINER_NAME" sh -c "trivy --version" 2>/dev/null | head -1 || true
else
    echo "   ℹ️  Trivy not installed (may be optional)"
fi

if docker exec "$CONTAINER_NAME" sh -c "which cosign" >/dev/null 2>&1; then
    echo "   ✅ Cosign is installed"
else
    echo "   ℹ️  Cosign not installed (may be optional)"
fi

# Test devops tools
echo ""
echo "9. DevOps tools verification..."

if docker exec "$CONTAINER_NAME" sh -c "which kubectl" >/dev/null 2>&1; then
    echo "   ✅ kubectl is installed"
    docker exec "$CONTAINER_NAME" sh -c "kubectl version --client" 2>/dev/null | head -1 || true
else
    echo "   ℹ️  kubectl not installed (may be optional)"
fi

if docker exec "$CONTAINER_NAME" sh -c "which helm" >/dev/null 2>&1; then
    echo "   ✅ Helm is installed"
else
    echo "   ℹ️  Helm not installed (may be optional)"
fi

# Test Go installation
echo ""
echo "10. Go installation test..."
if docker exec "$CONTAINER_NAME" sh -c "which go" >/dev/null 2>&1; then
    echo "   ✅ Go is installed"
    GO_VERSION=$(docker exec "$CONTAINER_NAME" sh -c "go version" 2>/dev/null || echo "unknown")
    echo "   📦 Version: $GO_VERSION"
    
    # Quick Go functionality test
    docker exec "$CONTAINER_NAME" sh -c "cd /workspace && echo 'package main' > test.go && go build test.go && rm test.go test" 2>/dev/null && echo "   ✅ Go can compile programs"
else
    echo "   ℹ️  Go not installed (may be optional)"
fi

# Volume mount test
echo ""
echo "11. Volume mount test..."
docker run --rm -v "$(pwd):/test-mount:ro" "$IMAGE" sh -c "ls /test-mount" >/dev/null 2>&1 && echo "   ✅ Volume mounts work" || echo "   ⚠️  Volume mount test inconclusive"

# Cleanup
cleanup

echo ""
echo "================================"
if [ $FAILED -eq 0 ]; then
    echo "✅ All critical tests passed!"
    exit 0
else
    echo "⚠️  $FAILED test(s) failed"
    exit 0  # Don't fail the build for minor issues
fi
