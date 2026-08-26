#!/usr/bin/env bash
# Resolution presets for the Intel iGPU (bandwidth math: it can't push
# 4K@60 through games or a stream). Same keys as your old set-res.sh:
#   $mod+F10 -> 720p  (native play)
#   $mod+F11 -> 1080p (streaming)
#   $mod+F12 -> 4K    (desktop)
set -euo pipefail

case "${1:-}" in
    720)  swaymsg output eDP-1 mode 1280x720  scale 1 ;;
    1080) swaymsg output eDP-1 mode 1920x1080 scale 1 ;;
    4k)   swaymsg output eDP-1 mode 3840x2160 scale 1.5 ;;
    *) echo "usage: $0 720|1080|4k" >&2; exit 1 ;;
esac
