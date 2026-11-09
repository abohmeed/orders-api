#!/usr/bin/env bash
# Off-camera: zoom the takebot Chrome page so Actions denial text is readable.
set -euo pipefail
CDP="${TAKEBOT_CDP_PORT:-9222}"
SCALE="${1:-1.75}"
page=$(curl -sf "http://127.0.0.1:${CDP}/json/list" | python3 -c '
import sys, json
pages = [t for t in json.load(sys.stdin) if t.get("type") == "page"]
assert pages, "no chrome pages"
pick = next((p for p in pages if "github.com" in p.get("url", "")), pages[0])
print(pick["webSocketDebuggerUrl"])
')
node - "$page" "$SCALE" <<'NODE'
const [uri, scale] = process.argv.slice(2);
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
    const t = setTimeout(() => reject(new Error("cdp timeout " + method)), 8000);
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
await call("Emulation.setPageScaleFactor", { pageScaleFactor: Number(scale) });
// Also bump CSS zoom as a fallback when Emulation is ignored.
await call("Runtime.evaluate", {
  expression: `document.body.style.zoom='${Number(scale)}'; true`,
  returnByValue: true,
});
console.log("zoom=" + scale);
ws.close();
NODE
