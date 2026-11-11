#!/usr/bin/env bash
# Hide VS Code bottom panel so the editor fills the window.
# Idempotent Close Panel via palette — not ctrl+j (toggle).
# Never fail the take: always print panel-closed and exit 0.
set +e
export DISPLAY="${DISPLAY:-:0}"
w=""
for rx in \
  'orders-api \[SSH: lab\]' \
  'start \[SSH: lab\]' \
  '\[SSH: lab\]' \
  'orders-api \[SSH: dop-rec\]' \
  'start \[SSH: dop-rec\]' \
  '\[SSH: dop-rec\]'
do
  w="$(xdotool search --name "$rx" 2>/dev/null | head -1)"
  [ -n "$w" ] && break
done
if [ -n "$w" ]; then
  timeout 3 xdotool windowactivate --sync "$w" >/dev/null 2>&1
  sleep 0.2
  xdotool key --clearmodifiers ctrl+shift+p >/dev/null 2>&1
  sleep 0.5
  xdotool type --delay 5 -- 'View: Close Panel' >/dev/null 2>&1
  sleep 0.4
  xdotool key Return >/dev/null 2>&1
  sleep 0.5
fi
echo panel-closed
exit 0
