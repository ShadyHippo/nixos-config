#!/usr/bin/env bash
# Toggle blueman-manager (Bluetooth manager UI) — mirror of pavucontrol-toggle.sh.
# Running? kill it (toggle closed). Not running? launch it (toggle open).
# The sway for_window rules float it and anchor it top-right near the tray.
#
# DETECTION: `pgrep -f '[b]lueman'` style match on the full command line —
# the `[b]` trick avoids matching this script's own `blueman-manager` arg.
# blueman-applet (the tray icon) does NOT match 'blueman-manager', so killing
# the manager never kills the tray.
if pgrep -f '[b]lueman-manager' >/dev/null 2>&1; then
  pkill -f '[b]lueman-manager'
else
  blueman-manager >/dev/null 2>&1 &
fi