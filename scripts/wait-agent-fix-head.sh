#!/usr/bin/env bash
# Off-camera (#325): wait until agent-fix exists for THIS HEAD before
# on-camera `gh pr checks --watch`. Stale prior-SHA rows flip to
# "no checks reported" right after push and make --watch exit 1.
set -euo pipefail
HEAD=$(git rev-parse HEAD)
for i in $(seq 120); do
  out=$(gh pr checks 2>&1 || true)
  if echo "$out" | grep -qi "no checks reported"; then
    sleep 2
    continue
  fi
  if ! echo "$out" | grep -Eiq "agent-fix"; then
    sleep 2
    continue
  fi
  rid=$(gh run list --commit "$HEAD" --workflow=agent-fix.yml -L 1 --json databaseId -q '.[0].databaseId' 2>/dev/null || true)
  if echo "$rid" | grep -q '^[0-9][0-9]*$'; then
    echo "agent-fix ready head=$HEAD run=$rid"
    exit 0
  fi
  sleep 2
done
echo "no agent-fix for HEAD after wait" >&2
gh pr checks || true
gh run list --commit "$HEAD" -L 5 || true
exit 1
