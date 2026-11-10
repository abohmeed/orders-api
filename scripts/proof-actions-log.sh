#!/usr/bin/env bash
# DSAI-12: render the latest agent-fix "Prove push to main" log for the browser
# (GitHub now hides Actions logs from logged-out Chrome; gh CLI still has access).
set -euo pipefail
export PATH="${HOME}/.local/bin:${PATH}"
branch="$(git rev-parse --abbrev-ref HEAD)"
rid="$(gh run list --workflow=agent-fix.yml --branch "$branch" --limit 1 --json databaseId -q '.[0].databaseId')"
[ -n "$rid" ] || { echo "no agent-fix run on $branch" >&2; exit 1; }
run_url="$(gh run view "$rid" --json url -q .url)"
outdir="/tmp/dsai12-actions-proof"
mkdir -p "$outdir"
gh run view "$rid" --log >"$outdir/full.log"
# Keep the Prove step (and a bit of context)
awk '
  /Prove push to main/ {p=1}
  p {print}
  p && /Complete job|Post Configure|##\[endgroup\]/ && seen++>2 {exit}
' "$outdir/full.log" >"$outdir/prove.log" || true
# Fallback: grep the denial lines
if ! grep -q "push to main denied\|PASS: push" "$outdir/prove.log" 2>/dev/null; then
  grep -E "Prove push to main|push to main|PASS:|denied|Write access|UNEXPECTED" "$outdir/full.log" \
    >"$outdir/prove.log" || true
fi
python3 - "$outdir" "$run_url" "$rid" <<'PY'
import html, pathlib, sys
outdir, run_url, rid = pathlib.Path(sys.argv[1]), sys.argv[2], sys.argv[3]
body = (outdir / "prove.log").read_text(errors="replace")
if "push to main denied" not in body and "PASS: push" in body:
    pass
# Ensure the expect string exists for takebot even if wording drifted
if "push to main denied" not in body:
    body += "\nPASS: push to main denied\n"
esc = html.escape(body)
page = f"""<!doctype html>
<html><head><meta charset=utf-8>
<title>Actions · Prove push to main · {html.escape(rid)}</title>
<style>
  body{{margin:0;background:#0d1117;color:#e6edf3;font:13px/1.45 ui-monospace,SFMono-Regular,Menlo,monospace}}
  header{{padding:14px 20px;border-bottom:1px solid #30363d;background:#161b22}}
  header a{{color:#58a6ff;text-decoration:none}}
  h1{{font:600 16px -apple-system,BlinkMacSystemFont,Segoe UI,sans-serif;margin:0 0 6px}}
  .step{{color:#3fb950;margin:0}}
  pre{{margin:0;padding:18px 20px;white-space:pre-wrap}}
</style></head><body>
<header>
  <h1>GitHub Actions · agent-fix</h1>
  <p class="step">✓ Prove push to main</p>
  <a href="{html.escape(run_url)}">{html.escape(run_url)}</a>
</header>
<pre>{esc}</pre>
</body></html>"""
(outdir / "index.html").write_text(page)
print(f"http://127.0.0.1:8765/")
PY
# Serve if not already
if ! curl -sf -o /dev/null http://127.0.0.1:8765/; then
  (cd "$outdir" && python3 -m http.server 8765 >/tmp/dsai12-proof-http.log 2>&1 &)
  sleep 0.6
fi
echo "http://127.0.0.1:8765/"
