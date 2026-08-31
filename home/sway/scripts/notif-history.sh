#!/usr/bin/env bash
# Mako notification history in fuzzel (keys.sh edition, viewer only).
# Lists everything in mako's history buffer — notifications that expired or
# were dismissed — newest first. Type to filter, Enter/Esc closes. Selection
# is just for reading (makoctl has no "delete from history").
set -euo pipefail

entries=$(makoctl history -j \
  | jq -r 'reverse | .[] | "\(.id)\t\(.app_name // .desktop_entry // .app_icon // "unknown")\t\(.summary // "")\t\(.body // "" | gsub("\\s+"; " ") | .[0:80])"')

if [[ -z "$entries" ]]; then
  entries="no notifications in history"
fi

printf '%s\n' "$entries" \
  | fuzzel --dmenu --width=80 --lines=15 --prompt="notifications > " > /dev/null