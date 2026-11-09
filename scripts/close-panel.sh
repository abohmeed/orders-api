#!/usr/bin/env bash
# DSAI-12 #526: hide VS Code bottom panel so the editor fills the window
# (agent-fix.yml / oidc.tf readable). Idempotent Close Panel via palette —
# not ctrl+j (toggle would re-open an already-closed panel).
set -euo pipefail
export DISPLAY="${DISPLAY:-:0}"
rx='start \[SSH: dop-rec\]'
w="$(xdotool search --name "$rx" 2>/dev/null | head -1 || true)"
if [ -z "$w" ]; then
  echo "close-panel: no VS Code window (ok)"
  exit 0
fi
timeout 5 xdotool windowactivate --sync "$w" >/dev/null
sleep 0.3
xdotool key --clearmodifiers ctrl+shift+p
sleep 0.6
xdotool type --delay 5 -- 'View: Close Panel'
sleep 0.5
xdotool key Return
sleep 0.8
# Also kill integrated terminals so an empty start$ pane cannot reappear.
xdotool key --clearmodifiers ctrl+shift+p
sleep 0.5
xdotool type --delay 5 -- 'Terminal: Kill All Terminals'
sleep 0.5
xdotool key Return
sleep 0.6
echo panel-closed
