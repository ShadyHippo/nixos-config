#!/usr/bin/env bash
# Resolution presets + proportional UI cascade.
#   $mod+F10 -> 720p  (native play)   $mod+F11 -> 1080p (streaming)   $mod+F12 -> 4K (desktop)
#
# The panel (Sharp 0x148D) exposes only ONE EDID mode (3840x2160@59997); sub-4K
# modes composite on the iGPU and the fixed-function scaler upscales to native.
# So every framebuffer px is 2 (1080p) or 3 (720p) physical px. Cursors, mouse
# accel and popup offsets are halved/thirded to keep them the same physical
# size; FONTS are deliberately NOT (1080p = 11pt, 720p = 10pt ghostty, tuned in
# modules/sizing.nix `presets`) — sized for readability on the grainy upscaled
# panel, not physical identity. Desktop output scale stays 1.0 everywhere.
#
# All numbers are baked from modules/sizing.nix (presets) at config time — edit
# sizing.nix, home-manager switch, then re-press the key. This script only
# edits the INSTALLED configs, so a later `home-manager switch` regenerates
# them to 4K base values (re-press a preset key to re-apply).
set -euo pipefail

preset="${1:?usage: $0 720|1080|4k}"

case "$preset" in
  720)  FACTOR="@FACTOR_720@" SCALE="@SCALE_720@" ACCEL="@ACCEL_720@"
        GTK_FONT="@GTK_FONT_720@" CURSOR="@CURSOR_720@"
        SWAY="@SWAY_720@" WAYBAR="@WB_720@" MAKO="@MAKO_720@" GHOST="@GHOST_720@" OSD="@OSD_720@" GTKINI_SED="@GTKINI_720@" ;;
  1080) FACTOR="@FACTOR_1080@" SCALE="@SCALE_1080@" ACCEL="@ACCEL_1080@"
        GTK_FONT="@GTK_FONT_1080@" CURSOR="@CURSOR_1080@"
        SWAY="@SWAY_1080@" WAYBAR="@WB_1080@" MAKO="@MAKO_1080@" GHOST="@GHOST_1080@" OSD="@OSD_1080@" GTKINI_SED="@GTKINI_1080@" ;;
  4k)   FACTOR="@FACTOR_4k@" SCALE="@SCALE_4k@" ACCEL="@ACCEL_4k@"
        GTK_FONT="@GTK_FONT_4k@" CURSOR="@CURSOR_4k@"
        SWAY="@SWAY_4k@" WAYBAR="@WB_4k@" MAKO="@MAKO_4k@" GHOST="@GHOST_4k@" OSD="@OSD_4k@" GTKINI_SED="@GTKINI_4k@" ;;
  *) echo "usage: $0 720|1080|4k" >&2; exit 1 ;;
esac

CFG="$HOME/.config/sway/config"
WB_JSON="$HOME/.config/waybar/config.jsonc"
WB_CSS="$HOME/.config/waybar/style.css"
MAKO_CFG="$HOME/.config/mako/config"
GHOST_CFG="$HOME/.config/ghostty/config"
OSD_CSS="$HOME/.config/swayosd/style.css"
GTKINI="$HOME/.config/gtk-3.0/settings.ini"
PRE="$HOME/.config/sway/preset"

# Serialize runs: two key presses overlapping would interleave the config seds
# and reloads (each bindsym exec runs concurrently). Wait for the previous run.
exec 9>"$HOME/.config/sway/set-res.lock"
flock 9

# 0) Close open volume/bluetooth popups. GDK_SCALE is fixed at LAUNCH, so an
#    already-open window cannot be rescaled — closing it now means the next
#    open is correctly-sized AND pre-positioned (the sway for_window rules run
#    at map time, so it appears in place — no teleport flash).
swaymsg '[app_id="(?i)pavucontrol"]' kill >/dev/null 2>&1 || true
swaymsg '[app_id="(?i)blueman-manager"]' kill >/dev/null 2>&1 || true

# 1) Sway: values + the output mode line all live in the config, applied by
#    `swaymsg reload`. Modes are the fragile part: switching CUSTOM→CUSTOM
#    modesets fails on this panel/iGPU (wlroots atomic commit EBUSY — previous
#    page-flip still pending; only NATIVE↔CUSTOM transitions work, verified
#    live: 4K→1080/720 and the reverse work, 1080↔720 don't). So sub-4K
#    presets force the transition THROUGH NATIVE: pass 1 strips the mode line
#    and reloads to native EDID, pass 2 writes the preset numbers + custom
#    mode line and reloads native→custom (the proven-good direction). The 4k
#    preset just strips the line and reloads to native. The sed patterns match
#    "any number after a stable key", so they work from any previous state.
sed -i '/^output eDP-1 mode/d' "$CFG"
if [ "$preset" = 4k ]; then
  printf '%s\n' "$SWAY" | sed -i -f /dev/stdin "$CFG"
  swaymsg reload || true
else
  swaymsg reload || true
  printf '%s\n' "$SWAY" | sed -i -f /dev/stdin "$CFG"
  swaymsg reload || true
fi

# 2) Waybar — SIGUSR2 reloads config+CSS in place (keeps the tray, no bar flash).
printf '%s\n' "$WAYBAR" | sed -i -f /dev/stdin "$WB_JSON"
printf '%s\n' "$WAYBAR" | sed -i -f /dev/stdin "$WB_CSS"
pkill -SIGUSR2 -x waybar || true

# 3) Mako (font/margin/padding/border) + Ghostty (font-size updates live via SIGUSR2).
printf '%s\n' "$MAKO" | sed -i -f /dev/stdin "$MAKO_CFG"
makoctl reload || true
printf '%s\n' "$GHOST" | sed -i -f /dev/stdin "$GHOST_CFG"
# nixpkgs renames the ELF to .ghostty-wrapped (comm: .ghostty-wrappe), so -x
# ghostty never matched and the reload was silently skipped. -xf matches the
# wrapper's preserved argv0 ("ghostty") exactly; -x .ghostty-wrappe is a
# comm-based fallback. SIGUSR2 = reload config only; terminals stay open.
pkill -SIGUSR2 -xf 'ghostty' 2>/dev/null || pkill -SIGUSR2 -x .ghostty-wrappe 2>/dev/null || true

# 4) swayosd — style.css is read at server start, so restart it via sway
#    (swaymsg exec keeps it tracked as sway's child; a full sway restart later
#    replaces it cleanly instead of ending up with two servers).
printf '%s\n' "$OSD" | sed -i -f /dev/stdin "$OSD_CSS"
# nixpkgs renames the swayosd-server ELF to .swayosd-server (comm is the dot
# name — same rename trick as ghostty), so -x swayosd-server matches nothing.
# The exec below then starts a fresh copy, picking up the new style.css.
pkill -x .swayosd-server 2>/dev/null || true
swaymsg exec swayosd-server

# 5) GTK cursor size in gtk-3.0/settings.ini (new XWayland apps read it at
#    launch) + live dconf values (font-name for GTK dialogs, cursor-size).
#    Best-effort (|| true): a gsettings failure must never abort the script
#    before the payload write + the "preset applied" toast below (it did once —
#    gsettings was missing from the system, so nothing past here ever ran).
printf '%s\n' "$GTKINI_SED" | sed -i -f /dev/stdin "$GTKINI"
# gsettings can't see schemas in sway's exec env (regreet doesn't source the
# profile XDG_DATA_DIRS that login shells get), so point at the schema dir
# directly. Resolved every run (survives rebuilds); empty = calls no-op below.
export GSETTINGS_SCHEMA_DIR="${GSETTINGS_SCHEMA_DIR:-$(ls -d /nix/store/*-gsettings-desktop-schemas-*/share/gsettings-schemas/*/glib-2.0/schemas 2>/dev/null | head -1)}"
gsettings set org.gnome.desktop.interface font-name "Cousine Nerd Font $GTK_FONT" || true
gsettings set org.gnome.desktop.interface cursor-size "$CURSOR" || true

# 6) Record the scale for app launchers (pavucontrol-toggle.sh, blueman wrapper)
#    so future opens match this preset.
printf 'SCALE=%s\n' "$SCALE" > "$PRE"

notify-send "$preset preset applied" "UI ×$FACTOR · mouse $ACCEL · volume/bluetooth closed — reopen: \$mod+b / volume icon"