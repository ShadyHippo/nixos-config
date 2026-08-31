#!/usr/bin/env bash
# Resolution presets for the Intel iGPU (bandwidth math: it can't push
# 4K@60 through games or a stream). Same keys as your old set-res.sh:
#   $mod+F10 -> 720p  (native play)
#   $mod+F11 -> 1080p (streaming)
#   $mod+F12 -> 4K    (desktop)
#
# The panel (Sharp 0x148D) only exposes ONE EDID mode (3840x2160@59997).
# Sub-4K resolutions are done via the panel fitter using `mode --custom`,
# which lets the iGPU composite at 720p/1080p and the fixed-function
# scaler upscale to native — the same trick xrandr used on X11.
#
# Restore to 4K via `swaymsg reload` (re-applies config = native EDID).
# mode 3840x2160@<Hz> is rejected by sway (verified live: both @59997 and @60), so no refresh-string path exists.
set -euo pipefail

case "${1:-}" in
    720)  swaymsg -- output eDP-1 mode --custom 1280x720  scale 1 ;;
    1080) swaymsg -- output eDP-1 mode --custom 1920x1080 scale 1 ;;
    4k)   swaymsg reload ;;
    *) echo "usage: $0 720|1080|4k" >&2; exit 1 ;;
esac
