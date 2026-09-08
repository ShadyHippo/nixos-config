#!/usr/bin/env bash
# Opens SA Mod Manager inside the SA2B Steam prefix (Wine/Proton).
# This is the ONLY supported way to run the manager. Never launch the
# GAME from inside the manager ("Save & Play") - launch it from Steam.
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXE="$DIR/SAModManager.exe"

if [ ! -f "$EXE" ]; then
    echo "ERROR: $EXE not found." >&2
    exit 1
fi
if ! command -v protontricks >/dev/null; then
    echo "ERROR: protontricks not found (should come from nixos-config modules/gaming.nix)." >&2
    exit 1
fi

exec protontricks-launch --appid 213610 "$EXE" "$@"
