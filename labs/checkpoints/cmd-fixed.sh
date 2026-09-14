#!/bin/bash
# Checkpoint: cmd-fixed
# Lesson(s) that use this: l013, l016 (start from this state after l008/l009 find the bug)
# Changes from day-one: Fix the CMD path from /orders-api to /app/orders-api
# Idempotent: yes

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$SCRIPT_DIR"

# Apply previous checkpoint
bash "labs/checkpoints/day-one.sh"

# Fix the Dockerfile CMD path
cat > Dockerfile << 'DOCKERFILE_EOF'
FROM golang:1.27-alpine

WORKDIR /app

COPY go.mod go.sum* ./
COPY . .

RUN go build -o /app/orders-api .

EXPOSE 8000

CMD ["/app/orders-api"]
DOCKERFILE_EOF

# Verify the fix was applied
if ! grep -q 'CMD \["/app/orders-api"\]' Dockerfile; then
	echo "ERROR: CMD path fix failed." >&2
	exit 1
fi

echo "checkpoint cmd-fixed ready"
