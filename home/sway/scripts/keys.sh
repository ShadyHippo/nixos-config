#!/usr/bin/env bash
# Searchable keybind reference (the regolith rofi-style dialog, fuzzel edition).
# Dumps every bindsym from the LIVE sway config into fuzzel --dmenu: type to
# filter, Esc to close. Selection is just for reading (not executed).
set -euo pipefail

grep -E '^[[:space:]]*bindsym' ~/.config/sway/config \
  | sed -E 's/^[[:space:]]*bindsym[[:space:]]+//' \
  | fuzzel --dmenu --width=60 --lines=30 --prompt="keybinds > "