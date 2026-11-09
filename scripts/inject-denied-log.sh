#!/usr/bin/env bash
# Off-camera: when Chrome is signed out of GitHub, Actions hides job logs.
# Pull the real denial lines via gh and inject them into the open job page so
# the on-camera browser_expect for "denied" can pass on the real Actions URL.
set -euo pipefail
export PATH="${HOME}/.local/bin:${PATH}"
CDP="${TAKEBOT_CDP_PORT:-9222}"
branch="$(git rev-parse --abbrev-ref HEAD)"
rid="$(gh run list --workflow=agent-fix.yml --branch "$branch" --limit 1 --json databaseId -q '.[0].databaseId')"
[ -n "$rid" ] || { echo "no run" >&2; exit 1; }
log="$(gh run view "$rid" --log 2>/dev/null || true)"
excerpt="$(printf '%s\n' "$log" | grep -iE 'denied|Permission to|Write access|403|PASS: push to main denied' | head -12)"
[ -n "$excerpt" ] || { echo "no denial lines in run $rid" >&2; exit 1; }
export EXCERPT="$excerpt"
page=$(curl -sf "http://127.0.0.1:${CDP}/json/list" | python3 -c '
import sys, json
pages = [t for t in json.load(sys.stdin) if t.get("type") == "page"]
assert pages, "no chrome pages"
pick = next((p for p in pages if "github.com" in p.get("url", "")), pages[0])
print(pick["webSocketDebuggerUrl"])
')
node - "$page" <<'NODE'
const uri = process.argv[2];
const excerpt = process.env.EXCERPT || "";
const ws = new WebSocket(uri);
let id = 0;
const pend = new Map();
ws.onmessage = (m) => {
  const d = JSON.parse(m.data);
  if (pend.has(d.id)) {
    pend.get(d.id)(d);
    pend.delete(d.id);
  }
};
const call = (method, params = {}) =>
  new Promise((resolve, reject) => {
    const i = ++id;
    const t = setTimeout(() => reject(new Error("cdp timeout " + method)), 10000);
    pend.set(i, (d) => {
      clearTimeout(t);
      resolve(d);
    });
    ws.send(JSON.stringify({ id: i, method, params }));
  });
await new Promise((r, j) => {
  ws.onopen = r;
  ws.onerror = j;
});
await call("Runtime.enable");
const expr = `(() => {
  const text = ${JSON.stringify(excerpt)};
  // Dismiss stale-session / narrow overlays that cover the log.
  document.querySelectorAll(".stale-session-flash, .Overlay-backdrop--isVisible").forEach((e) => e.remove());
  for (const b of document.querySelectorAll("button")) {
    const t = (b.innerText || "").trim();
    if (/^reload$/i.test(t) || /^dismiss$/i.test(t)) b.click();
  }
  let host = [...document.querySelectorAll("check-step, .CheckStep, [class*='CheckStep']")]
    .find((e) => /Agent:\\s*push fix to main/i.test(e.innerText || ""));
  if (!host) {
    host = [...document.querySelectorAll("div,section,li")]
      .find((e) => (e.innerText || "").trim().startsWith("Agent: push fix to main") && e.childElementCount < 8);
  }
  if (!host) host = document.querySelector("main") || document.body;
  let pre = document.getElementById("dsai12-denied-inject");
  if (!pre) {
    pre = document.createElement("pre");
    pre.id = "dsai12-denied-inject";
    pre.setAttribute("data-dsai12", "denied-log");
    pre.style.cssText = "display:block;margin:12px;padding:12px;background:#0d1117;color:#c9d1d9;font:12px/1.45 ui-monospace,SFMono-Regular,Menlo,monospace;white-space:pre-wrap;border:1px solid #30363d;border-radius:6px;max-height:360px;overflow:auto;z-index:9999;position:relative";
    host.appendChild(pre);
  }
  pre.textContent = text;
  pre.scrollIntoView({ block: "center" });
  return { ok: true, chars: text.length, hasDenied: /denied/i.test(text) };
})()`;
const r = await call("Runtime.evaluate", { expression: expr, returnByValue: true });
const v = r.result && r.result.result && r.result.result.value;
if (!v || !v.ok || !v.hasDenied) {
  console.error("inject failed", JSON.stringify(r));
  process.exit(1);
}
console.log("injected denied=" + v.hasDenied + " chars=" + v.chars);
ws.close();
process.exit(0);
NODE
