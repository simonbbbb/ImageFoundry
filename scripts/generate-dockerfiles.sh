#!/bin/bash
# Generate Dockerfiles from template and config
# Usage: ./scripts/generate-dockerfiles.sh [base-image...]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "[INFO] Delegating to Python generator..."
python3 "$PROJECT_ROOT/scripts/generate-dockerfiles.py" "$@"
