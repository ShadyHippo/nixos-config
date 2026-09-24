#!/usr/bin/env bash
# Jump to the next/prev CLEAN numbered desktop (1-10) for the gamepad's
# capture+trigger chord. Empty workspaces are destroyed when left, so a
# numbered desktop sway doesn't currently know about = clean; switching
# to it creates it empty. Notifies when every numbered desktop is taken.
set -euo pipefail

dir=${1:-next}
target=$(python3 - "$dir" <<'EOF'
import json, subprocess, sys

direction = sys.argv[1]
workspaces = json.loads(subprocess.check_output(["swaymsg", "-t", "get_workspaces"]))
focused = next((w["num"] for w in workspaces if w["focused"]), 0)
used = {w["num"] for w in workspaces}

step = 1 if direction == "next" else -1
for distance in range(1, 11):
    number = ((focused - 1 + step * distance) % 10) + 1
    if number not in used:
        print(number)
        break
else:
    print(0)
EOF
)

if [ "$target" != "0" ]; then
  exec swaymsg workspace number "$target"
fi

notify-send "Desktops" "All of desktops 1-10 are in use."
