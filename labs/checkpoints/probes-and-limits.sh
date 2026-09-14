#!/bin/bash
# Checkpoint: probes-and-limits
# Lesson(s) that use this: l022, l024, l025, l027, l032, l034, l037, l039, l041, l042, l044, l045, l047, l049, l051, l053, l054, l056, l060, l061, l064, l067, l071, l074
# Changes from dockerfile-fixed: Add readiness and liveness probes, resource requests and limits
# Idempotent: yes

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$SCRIPT_DIR"

# Apply previous checkpoint
bash "labs/checkpoints/dockerfile-fixed.sh"

# Update k8s/deployment.yaml with probes and resource limits
cat > k8s/deployment.yaml << 'DEPLOYMENT_EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: orders-api
  labels:
    app: orders-api
spec:
  replicas: 2
  selector:
    matchLabels:
      app: orders-api
  template:
    metadata:
      labels:
        app: orders-api
    spec:
      containers:
      - name: orders-api
        image: orders-api:dev
        imagePullPolicy: Never
        ports:
        - containerPort: 8000
          name: http
        readinessProbe:
          httpGet:
            path: /healthz
            port: 8000
          initialDelaySeconds: 5
          periodSeconds: 10
        livenessProbe:
          httpGet:
            path: /healthz
            port: 8000
          initialDelaySeconds: 15
          periodSeconds: 20
        resources:
          requests:
            memory: "64Mi"
            cpu: "250m"
          limits:
            memory: "128Mi"
            cpu: "500m"
DEPLOYMENT_EOF

# Validate manifest syntax with kubectl if available
if command -v kubectl &> /dev/null; then
	kubectl apply --dry-run=client -f k8s/deployment.yaml || true
fi

# Verify probes are present
if ! grep -q "readinessProbe:" k8s/deployment.yaml; then
	echo "ERROR: readinessProbe not found in deployment." >&2
	exit 1
fi

if ! grep -q "livenessProbe:" k8s/deployment.yaml; then
	echo "ERROR: livenessProbe not found in deployment." >&2
	exit 1
fi

if ! grep -q "path: /healthz" k8s/deployment.yaml; then
	echo "ERROR: /healthz path not found in probes." >&2
	exit 1
fi

# Verify resource limits are present
if ! grep -q "memory:" k8s/deployment.yaml; then
	echo "ERROR: memory limits not found in deployment." >&2
	exit 1
fi

echo "checkpoint probes-and-limits ready"
