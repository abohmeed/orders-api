#!/usr/bin/env bash
# Hide VS Code bottom panel so the editor fills the window.
# Idempotent Close Panel via palette — not ctrl+j (toggle would re-open).
# #602: always Escape after so command palette / find are never left open.
set -euo pipefail
export DISPLAY="${DISPLAY:-:0}"
rx='orders-api \[SSH: dop-rec\]|start \[SSH: dop-rec\]'
w="$(xdotool search --name "$rx" 2>/dev/null | head -1 || true)"
if [ -z "$w" ]; then
  w="$(xdotool search --class 'code' 2>/dev/null | head -1 || true)"
fi
if [ -z "$w" ]; then
  echo "close-panel: no VS Code window (ok)"
  exit 0
fi
timeout 5 xdotool windowactivate --sync "$w" >/dev/null
sleep 0.3
xdotool key --clearmodifiers Escape; sleep 0.15
xdotool key --clearmodifiers Escape; sleep 0.15
xdotool key --clearmodifiers ctrl+shift+p
sleep 0.6
xdotool type --delay 5 -- 'View: Close Panel'
sleep 0.5
xdotool key Return
sleep 0.5
xdotool key --clearmodifiers Escape; sleep 0.15
xdotool key --clearmodifiers Escape; sleep 0.2
echo panel-closed
