#!/bin/bash
set -euo pipefail

# Performance testing script for container images

IMAGE="${1:-}"
OUTPUT_FILE="${2:-performance-results.json}"

if [ -z "$IMAGE" ]; then
    echo "Usage: $0 <image-name> [output-file]"
    exit 1
fi

echo "⚡ Running performance tests for: $IMAGE"

# Check if hyperfine is available
if ! command -v hyperfine &> /dev/null; then
    echo "Installing hyperfine..."
    if command -v apt-get &> /dev/null; then
        wget -q https://github.com/sharkdp/hyperfine/releases/download/v1.18.0/hyperfine_1.18.0_amd64.deb
        sudo dpkg -i hyperfine_1.18.0_amd64.deb 2>/dev/null || true
        rm -f hyperfine_1.18.0_amd64.deb
    else
        echo "⚠️  hyperfine not available, using basic timing"
        USE_BASIC=1
    fi
fi

RESULTS_FILE=$(mktemp)
echo "{" > "$RESULTS_FILE"
echo "  \"image\": \"$IMAGE\"," >> "$RESULTS_FILE"
echo "  \"timestamp\": \"$(date -Iseconds)\"," >> "$RESULTS_FILE"
echo "  \"tests\": {" >> "$RESULTS_FILE"

# Test 1: Image pull time
echo ""
echo "1. Testing image pull time..."
docker rmi "$IMAGE" 2>/dev/null || true
if command -v hyperfine &> /dev/null; then
    PULL_TIME=$(hyperfine --runs 1 --show-output "docker pull $IMAGE" 2>&1 | grep -oP '(?<=Time ).*' | head -1 || echo "N/A")
else
    START_TIME=$(date +%s.%N)
    docker pull "$IMAGE" >/dev/null 2>&1
    END_TIME=$(date +%s.%N)
    PULL_TIME=$(echo "$END_TIME - $START_TIME" | bc 2>/dev/null || echo "unknown")
fi
echo "   Pull time: $PULL_TIME"
echo "    \"pull_time\": \"$PULL_TIME\"," >> "$RESULTS_FILE"

# Test 2: Container startup time
echo ""
echo "2. Testing container startup time..."
if command -v hyperfine &> /dev/null; then
    STARTUP_TIME=$(hyperfine --warmup 1 --runs 3 "docker run --rm $IMAGE echo 'ready'" 2>&1 | grep -oP '(?<=Time ).*' | head -1 || echo "N/A")
else
    START_TIME=$(date +%s.%N)
    docker run --rm "$IMAGE" echo "ready" >/dev/null 2>&1
    END_TIME=$(date +%s.%N)
    STARTUP_TIME=$(echo "$END_TIME - $START_TIME" | bc 2>/dev/null || echo "unknown")
fi
echo "   Startup time: $STARTUP_TIME"
echo "    \"startup_time\": \"$STARTUP_TIME\"," >> "$RESULTS_FILE"

# Test 3: Image size
echo ""
echo "3. Checking image size..."
SIZE_BYTES=$(docker images --format "{{.Size}}" "$IMAGE" | awk '{print $1}')
SIZE_MB=$(docker images --format "{{.Size}}" --filter "reference=$IMAGE" "$IMAGE" | grep -oE '[0-9.]+' | head -1)
echo "   Image size: $SIZE_BYTES"
echo "    \"image_size_raw\": \"$SIZE_BYTES\"," >> "$RESULTS_FILE"
echo "    \"image_size_mb\": $SIZE_MB," >> "$RESULTS_FILE"

# Test 4: Layer count
echo ""
echo "4. Counting image layers..."
LAYERS=$(docker inspect "$IMAGE" --format='{{len .RootFS.Layers}}')
echo "   Layer count: $LAYERS"
echo "    \"layer_count\": $LAYERS," >> "$RESULTS_FILE"

# Test 5: Disk usage inside container
echo ""
echo "5. Testing container disk usage..."
DISK_USAGE=$(docker run --rm "$IMAGE" sh -c "du -sh / 2>/dev/null | cut -f1" || echo "unknown")
echo "   Container disk usage: $DISK_USAGE"
echo "    \"disk_usage\": \"$DISK_USAGE\"," >> "$RESULTS_FILE"

# Test 6: Memory footprint
echo ""
echo "6. Testing memory footprint..."
CONTAINER_NAME="perf-test-$(date +%s)"
docker run -d --name "$CONTAINER_NAME" "$IMAGE" sleep 30 >/dev/null 2>&1 || true
sleep 1
MEMORY_USAGE=$(docker stats "$CONTAINER_NAME" --no-stream --format "{{.MemUsage}}" 2>/dev/null | cut -d'/' -f1 | tr -d ' ' || echo "unknown")
docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true
echo "   Memory usage: $MEMORY_USAGE"
echo "    \"memory_usage\": \"$MEMORY_USAGE\"," >> "$RESULTS_FILE"

# Test 7: Command execution speed
echo ""
echo "7. Testing command execution speed..."
if command -v hyperfine &> /dev/null; then
    CMD_TIME=$(hyperfine --warmup 2 --runs 5 "docker run --rm $IMAGE sh -c 'echo test && ls && pwd'" 2>&1 | grep -oP '(?<=Time ).*' | head -1 || echo "N/A")
else
    START_TIME=$(date +%s.%N)
    for i in {1..5}; do
        docker run --rm "$IMAGE" sh -c "echo test && ls && pwd" >/dev/null 2>&1
    done
    END_TIME=$(date +%s.%N)
    CMD_TIME=$(echo "($END_TIME - $START_TIME) / 5" | bc 2>/dev/null || echo "unknown")
fi
echo "   Command execution time: $CMD_TIME"
echo "    \"cmd_execution_time\": \"$CMD_TIME\"," >> "$RESULTS_FILE"

# Test 8: Concurrent container startup
echo ""
echo "8. Testing concurrent container startup..."
START_TIME=$(date +%s.%N)
for i in {1..5}; do
    docker run -d --name "concurrent-$i" "$IMAGE" sleep 10 >/dev/null 2>&1 &
done
wait
CONCURRENT_TIME=$(echo "$(date +%s.%N) - $START_TIME" | bc 2>/dev/null || echo "unknown")
for i in {1..5}; do
    docker rm -f "concurrent-$i" >/dev/null 2>&1 || true
done
echo "   Concurrent startup time (5 containers): ${CONCURRENT_TIME}s"
echo "    \"concurrent_startup_time\": \"$CONCURRENT_TIME\"" >> "$RESULTS_FILE"

# Close JSON
echo "  }" >> "$RESULTS_FILE"
echo "}" >> "$RESULTS_FILE"

# Move results to output file
mv "$RESULTS_FILE" "$OUTPUT_FILE"

echo ""
echo "✅ Performance tests completed!"
echo "Results saved to: $OUTPUT_FILE"
echo ""
echo "Summary:"
cat "$OUTPUT_FILE"
