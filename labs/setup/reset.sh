#!/bin/bash
set -e

# Reset the repository to its initial state (day-one state)
# This script is idempotent and can be run multiple times

# Get the repository root
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

# Reset all changes to git-tracked files
git checkout .

# Remove any untracked files except common excludes
git clean -fd \
  --exclude=.env \
  --exclude=.env.local \
  --exclude=bin/ \
  --exclude=terraform/.terraform \
  --exclude=terraform/.terraform.lock.hcl \
  --exclude=terraform/terraform.tfstate* \
  --exclude=node_modules/ \
  --exclude=dist/

echo "Repository reset to day-one state"
