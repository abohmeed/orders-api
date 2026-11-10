#!/usr/bin/env bash
# Hide VS Code/Cursor bottom panel so the editor fills the window.
# #738: NEVER open the command palette on camera. Use a prepare-installed
# keybinding for workbench.action.closePanel, then Escape to clear find/palette.
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
sleep 0.25
# Clear any open palette/find first
xdotool key --clearmodifiers Escape; sleep 0.12
xdotool key --clearmodifiers Escape; sleep 0.12
# workbench.action.closePanel via prepare keybinding (ctrl+alt+shift+[)
xdotool key --clearmodifiers ctrl+alt+shift+bracketleft
sleep 0.45
xdotool key --clearmodifiers Escape; sleep 0.12
xdotool key --clearmodifiers Escape; sleep 0.15
echo panel-closed
