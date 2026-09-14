#!/bin/bash
# Checkpoint: ci-pipeline
# Lesson(s) that use this: l044, l045, l047, l049, l051, l053, l054, l056, l060, l061, l064, l067, l071, l074
# Changes from configmap-support: Add GitHub Actions workflow with build-and-test job
# Idempotent: yes

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$SCRIPT_DIR"

# Apply previous checkpoint
bash "labs/checkpoints/configmap-support.sh"

# Create .github/workflows directory if it doesn't exist
mkdir -p .github/workflows

# Create the CI pipeline workflow
cat > .github/workflows/ci.yml << 'WORKFLOW_EOF'
name: CI

on:
  push:
    branches:
      - main
  pull_request:

jobs:
  build-and-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-go@v5
        with:
          go-version: "1.27"
      - name: Build Docker image
        run: docker build -t orders-api:test .
      - name: Run tests
        run: go test ./...
      - name: Run hadolint
        run: hadolint Dockerfile || true
WORKFLOW_EOF

# Validate workflow syntax with actionlint if available
if command -v actionlint &> /dev/null; then
	actionlint .github/workflows/ci.yml || true
fi

# Verify workflow file exists and has build-and-test job
if ! grep -q "build-and-test:" .github/workflows/ci.yml; then
	echo "ERROR: build-and-test job not found in workflow." >&2
	exit 1
fi

if ! grep -q "go test ./..." .github/workflows/ci.yml; then
	echo "ERROR: go test command not found in workflow." >&2
	exit 1
fi

echo "checkpoint ci-pipeline ready"
