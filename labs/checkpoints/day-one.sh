#!/bin/bash
# Checkpoint: day-one
# Lesson(s) that use this: l002, l008, l009, l013, l016
# Changes from previous: Initial clone with planted bug in CMD path
# Idempotent: yes

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$SCRIPT_DIR"

# Reset the repository to a clean state (day-one condition)
# If a git repo exists, reset it; otherwise indicate it's clean
if [ -d ".git" ]; then
	git checkout -- . 2>/dev/null || true
	git clean -fd -e 'labs' 2>/dev/null || true
fi

# Verify day-one state: planted bug in Dockerfile CMD
if ! grep -q 'CMD \["/orders-api"\]' Dockerfile; then
	echo "ERROR: Dockerfile does not have the planted CMD bug. This is not day-one state." >&2
	exit 1
fi

# Verify no /healthz endpoint exists
if grep -q "GET /healthz" main.go; then
	echo "ERROR: /healthz endpoint already exists. This is not day-one state." >&2
	exit 1
fi

# Verify no probes in deployment
if grep -q "readinessProbe" k8s/deployment.yaml; then
	echo "ERROR: Probes already added. This is not day-one state." >&2
	exit 1
fi

# Verify no ConfigMap support
if grep -q "ORDERS_CONFIG_SOURCE" main.go; then
	echo "ERROR: ConfigMap support already added. This is not day-one state." >&2
	exit 1
fi

# Verify no CI pipeline (workflow should be placeholder)
if grep -q "build-and-test" .github/workflows/ci.yml 2>/dev/null; then
	echo "ERROR: CI pipeline already configured. This is not day-one state." >&2
	exit 1
fi

echo "checkpoint day-one ready"
