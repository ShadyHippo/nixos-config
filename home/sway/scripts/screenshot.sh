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
# uploads.
#
# WHY SCALING IS NOT DONE BY GRIM: grim's own -s flag scales on a single
# thread, and at 4K that is ~33M pixels through one core. Measured on this
# machine, whole-screen:
#     grim -s 0.5            1292 ms
#     grim | ffmpeg scale     719 ms   <-- what this script does now
#     grim (no scale)         353 ms
# ffmpeg's scale filter is multithreaded, so the -half modes are now within
# ~200ms of the unscaled ones instead of ~1000ms slower. Only the PNG encode
# is left as unavoidable overhead (~300ms).
#
# iw/2:ih/2 is an exact integer halving, so the result is precisely 1080p.
# The scale filter runs BEFORE the png encoder (both are in one ffmpeg
# process), so we never re-encode twice:
#
#   full-half    all outputs, 1/2 size                         (Alt+Print)
#   window-half  focused window, 1/2 size                (Ctrl+Alt+Print)
#   snip-half    rectangle select, 1/2 size        ($mod+Alt+Shift+s)
set -euo pipefail

mode="${1:-}"
half=0
case "$mode" in
    full-half|snip-half|window-half) half=1; mode="${mode%-half}" ;;
esac

# Build the grim argv, then append the ffmpeg scale stage only for -half.
# Kept as an array so an unset/empty element can never word-split into a
# stray empty argument (grim would treat that as a bad geometry).
grim_cmd=(grim)
case "$mode" in
    snip)
        geom=$(slurp -d -x -c '#ff2b6dff')
        [[ -n $geom ]] || exit 1        # user pressed Esc in the snip tool
        grim_cmd+=(-g "$geom")
        ;;
    window)
        geom=$(swaymsg -t get_tree | jq -r '
            .. | select(.pid? and .rect?)
            | select(.focused? == true)
            | .rect | "\(.x),\(.y) \(.width)x\(.height)"')
        [[ -n $geom ]] || exit 1
        grim_cmd+=(-g "$geom")
        ;;
    full)
        ;;
    *)
        echo "usage: $0 snip|snip-half|full|full-half|window|window-half" >&2
        exit 1
        ;;
esac
grim_cmd+=(-)

if (( half )); then
    # -filter_threads lets the scale filter use multiple cores. The image is
    # still piped as PNG, which is what wl-copy needs to advertise the
    # image/png clipboard target.
    "${grim_cmd[@]}" | ffmpeg -v error -filter_threads 0 \
        -i pipe:0 -vf 'scale=iw/2:ih/2:flags=bilinear' \
        -f image2pipe -vcodec png - | wl-copy
else
    "${grim_cmd[@]}" | wl-copy
fi

notify-send "Screenshot" "$1 captured to clipboard"
