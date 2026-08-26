#!/usr/bin/env bash
# Screenshots -> clipboard only (no files), per spec:
#
#   snip    rectangle select with live pixel measurements (slurp -d),
#           Greenshot-style                                    ($mod+Shift+s)
#   window  focused window's exact geometry                     (Ctrl+Print)
#   full    all outputs                                         (Print)
set -euo pipefail

case "${1:-}" in
    snip)
        grim -g "$(slurp -d)" -
        ;;
    window)
        geo=$(swaymsg -t get_tree | jq -r '
            .. | select(.pid? and .rect?)
            | select(.focused? == true)
            | .rect | "\(.x),\(.y) \(.width)x\(.height)"')
        grim -g "$geo" -
        ;;
    full)
        grim -
        ;;
    *)
        echo "usage: $0 snip|window|full" >&2
        exit 1
        ;;
esac | wl-copy

notify-send "Screenshot" "$1 captured to clipboard"
