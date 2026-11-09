#!/usr/bin/env bash
set -euo pipefail
node <<'JS'
const http = require("http");
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
  await send("Runtime.evaluate", {
    expression: "document.getElementById('dsai12-revealed-log')?.remove(); document.documentElement.style.zoom='1'; 'revealed-cleared'",
    returnByValue: true,
  });
  console.log("revealed-cleared");
  ws.close();
})().catch((e) => { console.error(e); process.exit(1); });
JS
