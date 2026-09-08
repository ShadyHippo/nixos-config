#!/usr/bin/env bash
# =============================================================================
# SA2B modded setup - one-shot (re)installer for the EXACT known-good setup.
#
# Safe to re-run at any time (idempotent). It:
#   1. Backs up the vanilla resource/gd_PC/DLL/Win32/Data_DLL.dll
#      (only if no backup exists yet)
#   2. Installs the SA2 Mod Loader (v328) into the game
#   3. Restores the full mods/ payload: 7 mods + mods/.modloader
#      (loader settings, profiles, Codes.dat, Patches.dat, extlib)
#   4. Fixes the profile's GamePath for the current machine
#   5. Restores Config/UserConfig.cfg + Keyboard.cfg
#   6. Optionally installs prefix wine dependencies (for the Mod Manager GUI)
#
# Usage:
#   ./setup-sa2b.sh [--install-winetricks]
#
# Prerequisites:
#   - Sonic Adventure 2 installed via Steam (App ID 213610)
#   - Game launched at least once with Proton (prefix must exist)
#   - protontricks available (nixos-config/modules/gaming.nix provides it)
#
# After running: launch the game from STEAM (never from inside the manager).
# =============================================================================
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP="$DIR/backup"
APPID=213610

log()  { printf '\n\033[1;32m==> %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33mWARNING:\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }

# ----------------------------------------------------------------------------
# 0. Locate things
# ----------------------------------------------------------------------------
for s in "$HOME/.local/share/Steam" "$HOME/.steam/steam" "$HOME/.var/app/com.valvesoftware.Steam/data/Steam"; do
    [ -d "$s/steamapps" ] && STEAM_ROOT="$s" && break
done
[ -n "${STEAM_ROOT:-}" ] || die "Steam library not found. Set STEAM_ROOT and re-run."

GAME_DIR="${GAME_DIR:-$STEAM_ROOT/steamapps/common/Sonic Adventure 2}"
PFX="$STEAM_ROOT/steamapps/compatdata/$APPID/pfx"
LOADER_DLL="$BACKUP/mods/.modloader/SA2ModLoader.dll"
W32="$GAME_DIR/resource/gd_PC/DLL/Win32"

[ -f "$GAME_DIR/sonic2app.exe" ] || die "Game not found at: $GAME_DIR"
[ -d "$PFX" ] || die "Proton prefix not found at: $PFX (launch the game once via Steam first)."
[ -f "$LOADER_DLL" ] || die "Backup payload missing: $LOADER_DLL (did you restore the NAS archive?)"

log "Game dir : $GAME_DIR"
log "Prefix   : $PFX"

# ----------------------------------------------------------------------------
# 1. Vanilla backup of Data_DLL.dll (the DLL the loader replaces)
# ----------------------------------------------------------------------------
if [ -f "$W32/Data_DLL_orig.dll" ]; then
    log "Vanilla Data_DLL backup already present: Data_DLL_orig.dll"
elif cmp -s "$W32/Data_DLL.dll" "$LOADER_DLL"; then
    warn "Data_DLL.dll is already the loader but no vanilla backup exists!"
    warn "Run Steam > Properties > Installed Files > Verify integrity, then re-run this script."
    die "Refusing to continue: would have no vanilla Data_DLL.dll to fall back to."
else
    cp -a "$W32/Data_DLL.dll" "$W32/Data_DLL_orig.dll"
    log "Backed up vanilla Data_DLL.dll -> Data_DLL_orig.dll"
fi

# ----------------------------------------------------------------------------
# 2. Install the mod loader
#    sonic2app.exe loads resource/gd_PC/DLL/Win32/Data_DLL.dll; the loader is a
#    replacement for it. A copy also lives in the game root (convention of the
#    SA2 Mod Manager).
# ----------------------------------------------------------------------------
install -m 644 "$LOADER_DLL" "$GAME_DIR/SA2ModLoader.dll"
install -m 644 "$LOADER_DLL" "$W32/Data_DLL.dll"
log "Mod loader installed (v$(cat "$BACKUP/mods/.modloader/sa2mlver.txt" 2>/dev/null || echo '?'))"

# ----------------------------------------------------------------------------
# 3. Restore mods/ payload (7 mods + .modloader settings)
# ----------------------------------------------------------------------------
mkdir -p "$GAME_DIR/mods"
# Some mods ship read-only files (e.g. HD GUI's font backups); make them
# overwritable so re-running this script never gets stuck.
chmod -R u+w "$GAME_DIR/mods" 2>/dev/null || true
cp -a "$BACKUP/mods/." "$GAME_DIR/mods/"
rm -f "$GAME_DIR/mods/SA2ModLoader.ini"   # stale legacy file from the mismatch incident
log "Mods payload restored (7 mods + mods/.modloader)"

# ----------------------------------------------------------------------------
# 4. Fix GamePath inside the profile for THIS machine
#    (JSON needs backslashes escaped; wine paths look like Z:\home\...)
# ----------------------------------------------------------------------------
PROFILE="$GAME_DIR/mods/.modloader/profiles/Default.json"
command -v python3 >/dev/null || die "python3 not found (needed to fix the profile GamePath)."
python3 - "$PROFILE" "$GAME_DIR" <<'PY'
import json, sys
profile, game_dir = sys.argv[1], sys.argv[2]
BS = chr(92)  # single backslash, immune to any shell escaping
with open(profile, encoding="utf-8") as f:
    data = json.load(f)
data["GamePath"] = "Z:" + game_dir.replace("/", BS)
with open(profile, "w", encoding="utf-8") as f:
    json.dump(data, f, indent=2)
PY
log "Profile GamePath -> $GAME_DIR"

# ----------------------------------------------------------------------------
# 5. Restore launcher configs (windowed; the loader controls the real mode)
# ----------------------------------------------------------------------------
mkdir -p "$GAME_DIR/Config"
cp -a "$BACKUP/config/." "$GAME_DIR/Config/"
log "Config/UserConfig.cfg + Keyboard.cfg restored"

# ----------------------------------------------------------------------------
# 6. Optional: wine deps for the Mod Manager GUI (.NET 8 desktop + VC runtime)
# ----------------------------------------------------------------------------
WT_LOG="$PFX/winetricks.log"
have_verb() { touch "$WT_LOG" 2>/dev/null; grep -qx "$1" "$WT_LOG" 2>/dev/null; }
MISSING=""
for v in dotnetdesktop8 vcrun2013 vcrun2022; do
    have_verb "$v" || MISSING="$MISSING $v"
done
if [ -n "$MISSING" ]; then
    if [ "${1:-}" = "--install-winetricks" ]; then
        log "Installing prefix dependencies:$MISSING (this can take a while)"
        for v in $MISSING; do
            protontricks "$APPID" "$v"
        done
        log "Prefix dependencies installed."
    else
        warn "Prefix is missing wine deps:$MISSING"
        warn "Only needed for the Mod Manager GUI. Install with:  $0 --install-winetricks"
    fi
else
    log "Prefix wine deps already present (dotnetdesktop8, vcrun2013, vcrun2022)"
fi

# ----------------------------------------------------------------------------
# Done
# ----------------------------------------------------------------------------
cat <<EOF

=============================================================================
 Setup complete. Launch "Sonic Adventure 2" from STEAM and play.
 (It is already in the known-good state this bundle was snapshotted from.)

 To open the mod manager later:      "$(basename "$DIR")/launch-manager.sh"
 If a loader update is ever needed:  do it INSIDE the manager (never from a
                                     website download directly into the game)
 To undo mods entirely:              delete $W32/Data_DLL.dll
                                     and rename Data_DLL_orig.dll -> Data_DLL.dll
=============================================================================
EOF
