#!/usr/bin/env bash
# Off-camera (#325): when Chrome has no GitHub web session, Actions hides
# job logs behind "Sign in to view logs". Pull the real denial lines via gh
# and inject them into the already-open job page so "denied" is readable
# under the Agent push step (same job URL, real log text; zoom still applies).
set -euo pipefail
export PATH="${HOME}/.local/bin:${PATH}"
branch="$(git rev-parse --abbrev-ref HEAD)"
rid="$(gh run list --workflow=agent-fix.yml --branch "$branch" --limit 1 --json databaseId -q '.[0].databaseId')"
[ -n "$rid" ] || { echo "no agent-fix run" >&2; exit 1; }
tmp="$(mktemp)"
gh run view "$rid" --log >"$tmp" 2>/dev/null || true
grep -Ei 'denied|Permission to|PASS: push|Attempting push|remote: Permission' "$tmp" | head -40 >"${tmp}.lines"
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
    const already = document.getElementById("dsai12-revealed-log");
    if (already) already.remove();
    const pre = document.createElement("pre");
    pre.id = "dsai12-revealed-log";
    pre.style.cssText = "white-space:pre-wrap;font:14px/1.45 ui-monospace,SFMono-Regular,Menlo,monospace;background:#0d1117;color:#e6edf3;padding:16px;margin:12px;border:1px solid #30363d;border-radius:6px;max-height:70vh;overflow:auto;z-index:9999;position:relative";
    pre.textContent = logText;
    const anchor = [...document.querySelectorAll("[data-name], summary, h3, span, div")]
      .find((e) => /Agent:\\s*push fix to main/i.test(e.getAttribute("data-name") || e.textContent || ""));
    if (anchor && anchor.parentElement) {
      anchor.parentElement.insertAdjacentElement("afterend", pre);
    } else {
      (document.querySelector("main") || document.body).prepend(pre);
    }
    pre.scrollIntoView({ block: "center" });
    return { ok: true, hasDenied: /denied/i.test(logText), chars: logText.length };
  })()`;
  const r = await send("Runtime.evaluate", { expression: expr, returnByValue: true });
  const v = r.result && r.result.result && r.result.result.value;
  if (!v || !v.ok || !v.hasDenied) {
    console.error("inject failed", JSON.stringify(r));
    process.exit(1);
  }
  console.log("revealed denied chars=" + v.chars);
  ws.close();
})().catch((e) => { console.error(e); process.exit(1); });
JS
rm -f "$tmp" "${tmp}.lines"
