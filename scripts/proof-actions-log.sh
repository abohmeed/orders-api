#!/usr/bin/env bash
# DSAI-12: resolve the latest agent-fix job URL for the browser (real GitHub Actions UI).
# Prints RUN_URL then PR_URL (one per line). Caller captures them for takebot.
set -euo pipefail
export PATH="${HOME}/.local/bin:${PATH}"
branch="$(git rev-parse --abbrev-ref HEAD)"
rid="$(gh run list --workflow=agent-fix.yml --branch "$branch" --limit 1 --json databaseId -q '.[0].databaseId')"
[ -n "$rid" ] || { echo "no agent-fix run on $branch" >&2; exit 1; }
# Prefer the job URL so Chrome lands on the log, not the run summary.
job_url="$(gh run view "$rid" --json jobs -q '.jobs[0].url' 2>/dev/null || true)"
run_url="$(gh run view "$rid" --json url -q .url)"
url="${job_url:-$run_url}"
[ -n "$url" ] || { echo "no URL for run $rid" >&2; exit 1; }
pr_url="$(gh pr view --json url -q .url 2>/dev/null || true)"
[ -n "$pr_url" ] || pr_url="$(gh pr list --head "$branch" --json url -q '.[0].url')"
[ -n "$pr_url" ] || { echo "no PR URL for $branch" >&2; exit 1; }
# Sanity: denial must exist in the log (off camera).
gh run view "$rid" --log 2>/dev/null | grep -Eqi 'denied|Write access|Permission.*denied|403' \
  || { echo "run $rid log missing denial" >&2; exit 1; }
echo "$url"
echo "$pr_url"
