#!/bin/bash
# Checkpoint: review-step
# Lesson(s) that use this: l047, l049, l051, l053, l054, l056, l060, l061, l064, l067, l071, l074
# Changes from terraform-plan-job: Add review job that calls Claude API
# Idempotent: yes

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$SCRIPT_DIR"

# Apply previous checkpoint
bash "labs/checkpoints/terraform-plan-job.sh"

# Update the CI pipeline workflow to add review job
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

  review:
    runs-on: ubuntu-latest
    needs: [build-and-test]
    if: always() && github.event_name == 'pull_request'
    steps:
      - uses: actions/checkout@v4
      - name: Review manifests and Terraform
        run: |
          # Lesson 7.6: the review job calls the Messages API with the manifest and Terraform files
          MANIFESTS=$(find k8s -name "*.yaml" | head -5)
          TERRAFORM_FILES=$(find terraform -name "*.tf" | head -3)
          for file in $MANIFESTS $TERRAFORM_FILES; do
            if [ -f "$file" ]; then
              BODY=$(jq -n --arg content "Review this infrastructure file for best practices: $(cat "$file")" '{model: "claude-opus-5", max_tokens: 1024, messages: [{role: "user", content: $content}]}')
              REVIEW=$(curl -s https://api.anthropic.com/v1/messages \
                -H "x-api-key: ${{ secrets.ANTHROPIC_API_KEY }}" \
                -H "anthropic-version: 2025-06-01" \
                -H "content-type: application/json" \
                -d "$BODY" | jq -r '.content[0].text')
              echo "Review for $file:"
              echo "$REVIEW"
            fi
          done > /tmp/review.txt
      - name: Post review as PR comment
        run: gh pr comment "${{ github.event.pull_request.number }}" --body "$(cat /tmp/review.txt)"
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
WORKFLOW_EOF

# Validate workflow syntax with actionlint if available
if command -v actionlint &> /dev/null; then
	actionlint .github/workflows/ci.yml || true
fi

# Verify review job exists
if ! grep -q "review:" .github/workflows/ci.yml; then
	echo "ERROR: review job not found in workflow." >&2
	exit 1
fi

if ! grep -q "api.anthropic.com" .github/workflows/ci.yml; then
	echo "ERROR: Claude API call not found in workflow." >&2
	exit 1
fi

if ! grep -q "gh pr comment" .github/workflows/ci.yml; then
	echo "ERROR: PR comment step not found in workflow." >&2
	exit 1
fi

echo "checkpoint review-step ready"
