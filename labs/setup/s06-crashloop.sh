#!/bin/bash
set -e

# Setup for lesson 6.2 demo: inject a configuration that causes CrashLoopBackOff
# The Deployment is patched to set an invalid ORDERS_PORT that causes the app to fail on startup

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

# Check if the patch already exists (idempotent)
if grep -q "invalid-port" k8s/deployment.yaml; then
  echo "CrashLoop setup already applied"
  exit 0
fi

# Add the bad env var to the first container with yq, so it lands inside the container's env list
# whether or not the checkpoint's manifest already has one (an awk splice used to put it in the
# middle of the ports item, and the cluster never saw it — found 2026-09-14).
yq -i '.spec.template.spec.containers[0].env += [{"name": "ORDERS_PORT", "value": "invalid-port"}]' k8s/deployment.yaml

echo "CrashLoop setup applied: invalid ORDERS_PORT will cause container to fail"
