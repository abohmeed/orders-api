#!/usr/bin/env bash
# Off-camera (#325): when Chrome has no GitHub web session, Actions hides
# job logs behind "Sign in to view logs". Pull the real denial lines via gh
# and inject them as a direct child of document.body (not under aria-hidden
# step chrome) so takebot's document.body.innerText sees "denied".
set -euo pipefail
export PATH="${HOME}/.local/bin:${PATH}"
branch="$(git rev-parse --abbrev-ref HEAD)"
rid="$(gh run list --workflow=agent-fix.yml --branch "$branch" --limit 1 --json databaseId -q '.[0].databaseId')"
[ -n "$rid" ] || { echo "no agent-fix run" >&2; exit 1; }
tmp="$(mktemp)"
gh run view "$rid" --log >"$tmp" 2>/dev/null || true
grep -Ei 'denied|Permission to|PASS: push|Attempting push|remote: Permission' "$tmp" | head -40 >"${tmp}.lines"
# Strip ANSI CSI sequences for readable on-camera text
python3 - "${tmp}.lines" <<'PY'
import re,sys
p=sys.argv[1]
t=open(p,'rb').read().decode('utf-8','replace')
t=re.sub(r'\x1b\[[0-9;]*m','',t)
open(p,'w').write(t)
PY
if ! grep -Eiq 'denied' "${tmp}.lines"; then
  echo "no denial lines in run $rid" >&2
  exit 1
fi
export DSAI12_REVEAL_LOG_FILE="${tmp}.lines"
node <<'JS'
const http = require("http");
const fs = require("fs");
const logText = fs.readFileSync(process.env.DSAI12_REVEAL_LOG_FILE, "utf8");
function get(url) {
  return new Promise((res, rej) =>
    http.get(url, (r) => { let d = ""; r.on("data", (c) => (d += c)); r.on("end", () => res(JSON.parse(d))); }).on("error", rej)
  );
}
(async () => {
  const pages = await get("http://127.0.0.1:9222/json/list");
  const p = pages.find((t) => t.type === "page") || pages[0];
  const ws = new WebSocket(p.webSocketDebuggerUrl);
  await new Promise((r, j) => { ws.onopen = r; ws.onerror = j; });
  let id = 0;
  const send = (m, params) =>
    new Promise((res) => {
      const i = ++id;
      const fn = (e) => { const msg = JSON.parse(e.data); if (msg.id === i) { ws.removeEventListener("message", fn); res(msg); } };
      ws.addEventListener("message", fn);
      ws.send(JSON.stringify({ id: i, method: m, params }));
    });
  const expr = `(() => {
    const logText = ${JSON.stringify(logText)};
    document.getElementById("dsai12-revealed-log")?.remove();
    const box = document.createElement("div");
    box.id = "dsai12-revealed-log";
    box.setAttribute("role", "log");
    box.style.cssText = "position:fixed;left:32px;right:32px;top:96px;z-index:2147483647;background:#0d1117;color:#e6edf3;padding:20px;border:3px solid #f85149;border-radius:8px;max-height:60vh;overflow:auto;font:18px/1.45 ui-monospace,SFMono-Regular,Menlo,monospace;box-shadow:0 12px 48px rgba(0,0,0,.6)";
    const title = document.createElement("div");
    title.style.cssText = "font:700 20px/1.3 ui-sans-serif,system-ui;margin:0 0 12px;color:#f85149";
    title.textContent = "Agent: push fix to main — PASS: push to main denied";
    const pre = document.createElement("pre");
    pre.style.cssText = "margin:0;white-space:pre-wrap;font:inherit;color:inherit";
    pre.textContent = logText;
    box.appendChild(title);
    box.appendChild(pre);
    document.body.appendChild(box);
    const bodyHas = /denied/i.test(document.body.innerText || "");
    return { ok: true, bodyHas, chars: logText.length };
  })()`;
  const r = await send("Runtime.evaluate", { expression: expr, returnByValue: true });
  const v = r.result && r.result.result && r.result.result.value;
  if (!v || !v.ok || !v.bodyHas) {
    console.error("inject failed", JSON.stringify(r));
    process.exit(1);
  }
  console.log("revealed denied chars=" + v.chars);
  ws.close();
})().catch((e) => { console.error(e); process.exit(1); });
JS
rm -f "$tmp" "${tmp}.lines"
