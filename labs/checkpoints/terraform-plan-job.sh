#!/bin/bash
# Checkpoint: terraform-plan-job
# Lesson(s) that use this: l045, l047, l049, l051, l053, l054, l056, l060, l061, l064, l067, l071, l074
# Changes from ci-pipeline: Add terraform-plan job to GitHub Actions workflow
# Idempotent: yes

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$SCRIPT_DIR"

# Apply previous checkpoint
bash "labs/checkpoints/ci-pipeline.sh"

# Update the CI pipeline workflow to add terraform-plan job
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

  terraform-plan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: hashicorp/setup-terraform@v3
      - name: Terraform init
        run: terraform init -upgrade
        working-directory: terraform
      - name: Terraform plan
        run: terraform plan -out=tfplan
        working-directory: terraform
WORKFLOW_EOF

# Validate workflow syntax with actionlint if available
if command -v actionlint &> /dev/null; then
	actionlint .github/workflows/ci.yml || true
fi

# Verify terraform-plan job exists
if ! grep -q "terraform-plan:" .github/workflows/ci.yml; then
	echo "ERROR: terraform-plan job not found in workflow." >&2
	exit 1
fi

if ! grep -q "terraform init" .github/workflows/ci.yml; then
	echo "ERROR: terraform init step not found in workflow." >&2
	exit 1
fi

if ! grep -q "terraform plan" .github/workflows/ci.yml; then
	echo "ERROR: terraform plan step not found in workflow." >&2
	exit 1
fi

echo "checkpoint terraform-plan-job ready"
