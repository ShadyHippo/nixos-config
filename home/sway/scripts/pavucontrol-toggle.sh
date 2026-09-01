#!/usr/bin/env sh
# Toggle pavucontrol from the waybar volume icon on-click.
# If it's running, close it; if not, launch it. The sway for_window rule
# (floating + move position 2700 1700) anchors it on open.
#
# DETECTION (verified): the real pavucontrol process has:
#   comm    = `.pavucontrol-wr`   (a leading dot + `-wr` suffix, NOT `pavucontrol`)
#   exe     = .../.pavucontrol-wrapped
#   cmdline = `pavucontrol`  (bare name — a `-f '/bin/pavucontrol'` match does NOT hit it)
# So match on the process-name form `.pavucontrol-wr`, which is stable. Using
# `pavucontrol` (no -f) would also self-match other processes, and `-f pavucontrol`
# matches this script's own argv too. `.pavucontrol-wr` is unambiguous.
#
# X11 (XWayland) backend is REQUIRED for scaling: GTK3's Wayland backend ignores
# GDK_SCALE (verified — identical window size on native Wayland), while the X11
# backend honors it. @PAV_SCALE@ comes from modules/sizing.nix (display.gtk.pavucontrol).
if pgrep -x '.pavucontrol-wr' >/dev/null 2>&1; then
  pkill -x '.pavucontrol-wr'
else
  GDK_BACKEND=x11 GDK_SCALE=@PAV_SCALE@ pavucontrol >/dev/null 2>&1 &
fi
