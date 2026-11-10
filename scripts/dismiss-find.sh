#!/usr/bin/env bash
# #602: leave no find/palette widget visible after goto.
set -euo pipefail
export DISPLAY="${DISPLAY:-:0}"
xdotool key --clearmodifiers Escape Escape >/dev/null 2>&1 || true
echo find-dismissed
