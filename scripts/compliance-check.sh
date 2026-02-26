#!/bin/bash
set -euo pipefail

# Compliance checking script for container images
# Checks against CIS Docker Benchmark and other security standards

IMAGE="${1:-}"
OUTPUT_DIR="${2:-compliance-reports}"

if [ -z "$IMAGE" ]; then
    echo "Usage: $0 <image-name> [output-directory]"
    echo "Example: $0 ghcr.io/myorg/myimage:latest"
    exit 1
fi

echo "🔍 Running compliance checks for: $IMAGE"
mkdir -p "$OUTPUT_DIR"

# Pull the image
echo "Pulling image..."
docker pull "$IMAGE"

# Run Docker Bench Security
echo "Running Docker Bench Security..."
if docker run --rm --net host --pid host --userns host \
    --cap-add audit_control \
    -e DOCKER_CONTENT_TRUST=0 \
    -v /var/lib:/var/lib \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v /usr/lib/systemd:/usr/lib/systemd \
    -v /etc:/etc \
    --label docker_bench_security \
    docker/docker-bench-security \
    -c container_images,container_runtime > "$OUTPUT_DIR/docker-bench-results.txt" 2>&1; then
    echo "✅ Docker Bench Security passed"
else
    echo "⚠️ Docker Bench Security found issues (see $OUTPUT_DIR/docker-bench-results.txt)"
fi

# Run custom CIS checks
echo "Running CIS Docker Benchmark checks..."

cat > "$OUTPUT_DIR/cis-checks.sh" << 'EOF'
#!/bin/bash
# CIS Docker Benchmark checks

IMAGE="$1"
CONTAINER_NAME="cis-test-$(date +%s)"
REPORT_FILE="$2/cis-report.txt"

echo "CIS Docker Benchmark Report - $(date)" > "$REPORT_FILE"
echo "Image: $IMAGE" >> "$REPORT_FILE"
echo "=====================================" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

# Start container
docker run -d --name "$CONTAINER_NAME" "$IMAGE" sleep 300

# CIS 4.1 - Ensure that a user for the container has been created
echo "CIS 4.1 - Checking container user..." >> "$REPORT_FILE"
USER=$(docker inspect "$CONTAINER_NAME" --format='{{.Config.User}}')
if [ -n "$USER" ] && [ "$USER" != "0" ] && [ "$USER" != "root" ]; then
    echo "  ✅ PASS: Container runs as non-root user: $USER" >> "$REPORT_FILE"
else
    echo "  ❌ FAIL: Container runs as root" >> "$REPORT_FILE"
fi

# CIS 4.6 - Ensure that HEALTHCHECK instructions have been added
echo "" >> "$REPORT_FILE"
echo "CIS 4.6 - Checking HEALTHCHECK..." >> "$REPORT_FILE"
HEALTHCHECK=$(docker inspect "$CONTAINER_NAME" --format='{{.Config.Healthcheck}}')
if [ "$HEALTHCHECK" != "<nil>" ]; then
    echo "  ✅ PASS: HEALTHCHECK is configured" >> "$REPORT_FILE"
else
    echo "  ⚠️ WARN: HEALTHCHECK not configured" >> "$REPORT_FILE"
fi

# CIS 4.9 - Ensure that COPY is used instead of ADD
echo "" >> "$REPORT_FILE"
echo "CIS 4.9 - Checking for ADD vs COPY..." >> "$REPORT_FILE"
echo "  ℹ️ INFO: Check Dockerfile manually for ADD usage" >> "$REPORT_FILE"

# CIS 4.10 - Ensure that secrets are not stored in environment variables
echo "" >> "$REPORT_FILE"
echo "CIS 4.10 - Checking environment variables for secrets..." >> "$REPORT_FILE"
ENVS=$(docker inspect "$CONTAINER_NAME" --format='{{range .Config.Env}}{{.}}\n{{end}}')
SECRET_PATTERNS="PASSWORD|PASSWD|PWD|SECRET|TOKEN|KEY|API_KEY|APIKEY|PRIVATE_KEY"
if echo "$ENVS" | grep -qiE "$SECRET_PATTERNS"; then
    echo "  ⚠️ WARN: Potential secrets found in environment variables" >> "$REPORT_FILE"
else
    echo "  ✅ PASS: No obvious secrets in environment variables" >> "$REPORT_FILE"
fi

# CIS 4.11 - Ensure that sensitive data is removed from images
echo "" >> "$REPORT_FILE"
echo "CIS 4.11 - Checking for sensitive files..." >> "$REPORT_FILE"
docker exec "$CONTAINER_NAME" sh -c "find / -name '*.pem' -o -name '*.key' -o -name '*.p12' -o -name '*.pfx' 2>/dev/null" | head -20 >> "$REPORT_FILE" || true

# Cleanup
docker rm -f "$CONTAINER_NAME" > /dev/null 2>&1

echo "" >> "$REPORT_FILE"
echo "Report completed: $(date)" >> "$REPORT_FILE"
EOF

chmod +x "$OUTPUT_DIR/cis-checks.sh"
"$OUTPUT_DIR/cis-checks.sh" "$IMAGE" "$OUTPUT_DIR"

# Check image size
echo "Checking image size..."
SIZE=$(docker images --format "{{.Size}}" "$IMAGE")
echo "Image size: $SIZE"
echo "Image size: $SIZE" >> "$OUTPUT_DIR/cis-report.txt"

# Run Trivy config scan for Dockerfile issues
echo "Running Trivy configuration scan..."
if command -v trivy &> /dev/null; then
    trivy image --scanners misconfig "$IMAGE" > "$OUTPUT_DIR/trivy-misconfig.txt" 2>&1 || true
fi

# Check for latest image updates
echo "Checking for security updates..."
docker run --rm "$IMAGE" sh -c "
    if command -v apt-get >/dev/null 2>&1; then
        apt-get update -qq && apt list --upgradable 2>/dev/null || true
    elif command -v apk >/dev/null 2>&1; then
        apk update && apk upgrade --simulate || true
    fi
" > "$OUTPUT_DIR/available-updates.txt" 2>&1 || true

echo ""
echo "✅ Compliance checks completed!"
echo "Reports saved to: $OUTPUT_DIR/"
echo ""
echo "Files generated:"
ls -la "$OUTPUT_DIR/"
