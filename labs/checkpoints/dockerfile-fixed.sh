#!/bin/bash
# Checkpoint: dockerfile-fixed
# Lesson(s) that use this: l019, l020, l021, l022, l024, l025, l027
# Changes from cmd-fixed: Multi-stage Dockerfile with builder and runtime stages
# Idempotent: yes

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$SCRIPT_DIR"

# Apply previous checkpoint
bash "labs/checkpoints/cmd-fixed.sh"

# Replace Dockerfile with multi-stage build
cat > Dockerfile << 'DOCKERFILE_EOF'
FROM golang:1.27-alpine AS builder

WORKDIR /app

COPY go.mod go.sum* ./
COPY . .

RUN go build -o /app/orders-api .

FROM alpine:3.20

WORKDIR /app
COPY --from=builder /app/orders-api /app/orders-api

EXPOSE 8000

CMD ["/app/orders-api"]
DOCKERFILE_EOF

# Validate with hadolint if available
if command -v hadolint &> /dev/null; then
	hadolint Dockerfile || true
fi

# Verify the multi-stage build structure
if ! grep -q "FROM golang:1.27-alpine AS builder" Dockerfile; then
	echo "ERROR: Builder stage not found in Dockerfile." >&2
	exit 1
fi

if ! grep -q "FROM alpine:3.20" Dockerfile; then
	echo "ERROR: Runtime stage not found in Dockerfile." >&2
	exit 1
fi

if ! grep -q "COPY --from=builder /app/orders-api /app/orders-api" Dockerfile; then
	echo "ERROR: Binary copy from builder not found in Dockerfile." >&2
	exit 1
fi

echo "checkpoint dockerfile-fixed ready"
