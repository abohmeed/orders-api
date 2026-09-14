#!/bin/bash
set -e

# Setup for lesson 6.4 lab: inject a Service selector mismatch
# The Service selector is changed so it doesn't match any pods, causing routing to fail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

# Check if the patch already exists (idempotent)
if grep -q "app: wrong-label" k8s/service.yaml; then
  echo "Selector mismatch setup already applied"
  exit 0
fi

# Patch the service selector to have a wrong label
# This creates a situation where the Service exists but routes nowhere

sed -i 's/app: orders-api/app: wrong-label/' k8s/service.yaml

echo "Selector mismatch setup applied: Service now has selector app=wrong-label"
