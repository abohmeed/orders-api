#!/usr/bin/env bash
# DSAI-12: wait until agent-fix on this branch succeeds (short name for takebot echo-match).
set -euo pipefail
branch="$(git rev-parse --abbrev-ref HEAD)"
for i in $(seq 1 60); do
  rid="$(gh run list --workflow=agent-fix.yml --branch "$branch" --limit 1 --json databaseId,status,conclusion,headSha \
    -q '.[0] | select(.headSha=="'"$(git rev-parse HEAD)"'") | "\(.databaseId) \(.status) \(.conclusion)"' 2>/dev/null || true)"
  if [ -z "$rid" ]; then
    echo "waiting for agent-fix run on $branch ($i)"
    sleep 5
    continue
  fi
  set -- $rid
  id=$1; st=$2; conc=${3:-}
  echo "agent-fix $id status=$st conclusion=$conc"
  if [ "$st" = completed ]; then
    [ "$conc" = success ] && { echo "agent-fix pass"; exit 0; }
    echo "agent-fix failed: $conc"; exit 1
  fi
  gh run watch "$id" --exit-status
  echo "agent-fix pass"
  exit 0
done
echo "agent-fix timeout"; exit 1
