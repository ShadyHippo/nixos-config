#!/usr/bin/env bash
# Screenshots -> clipboard only (no files), per spec:
#
#   snip    rectangle select with live pixel measurements (slurp -d),
#           Greenshot-style                                    ($mod+Shift+s)
#   window  focused window's exact geometry                     (Ctrl+Print)
#   full    all outputs                                         (Print)
#
# Any mode may be suffixed with "-half" to downscale the result to 1/2
# linear size (3840x2160 -> 1920x1080) for chats/forums that choke on 4K
# uploads. Scaling is done by grim's own -s flag, so no ImageMagick is
# involved and the result is exactly 1080p, not 1080p-ish:
#
#   full-half    all outputs, 1/2 size                         (Alt+Print)
#   window-half  focused window, 1/2 size                (Ctrl+Alt+Print)
#   snip-half    rectangle select, 1/2 size        ($mod+Alt+Shift+s)
set -euo pipefail

mode="${1:-}"
grim_args=()
case "$mode" in
    full-half|snip-half|window-half) grim_args=(-s 0.5); mode="${mode%-half}" ;;
esac

case "$mode" in
    snip)
        grim "${grim_args[@]}" -g "$(slurp -d -x -c '#ff2b6dff')" -
        ;;
    window)
        geo=$(swaymsg -t get_tree | jq -r '
            .. | select(.pid? and .rect?)
            | select(.focused? == true)
            | .rect | "\(.x),\(.y) \(.width)x\(.height)"')
        grim "${grim_args[@]}" -g "$geo" -
        ;;
    full)
        grim "${grim_args[@]}" -
        ;;
    *)
        echo "usage: $0 snip|snip-half|full|full-half|window|window-half" >&2
        exit 1
        ;;
esac | wl-copy

notify-send "Screenshot" "$1 captured to clipboard"
