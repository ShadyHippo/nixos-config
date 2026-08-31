#!/usr/bin/env bash
# Waybar custom/disk: matches Dolphin's used% = (total - user_avail)/total.
# Waybar's built-in disk module computes from root-reserved blocks (f_bfree),
# which under-reports by ~5% (the ext4 reserved-for-root blocks) - e.g. it read
# 13% while Dolphin said 19%. This reads df's user-available column instead.
#
# Emits the REAL UTF-8 bytes for U+F02CA (\U in bash printf takes 8 hex digits),
# NOT a "\u" JSON escape. This was the bug: JSON's \uXXXX is only 4 hex digits,
# so "\uF02CA" decoded as U+F02C (fa-tags) + a stray 'A'. UTF-8 is legal in a
# JSON string, so emitting the actual bytes renders md-harddisk cleanly.
read -r total avail < <(df -B1 --output=size,avail / | tail -1)
if [[ -z "$total" || -z "$avail" ]]; then
  printf '{"text":"\U000F02CA 0%%"}'
  exit 0
fi
n="$(awk -v t="$total" -v a="$avail" 'BEGIN{ printf "%d", (t-a)/t*100 + 0.5 }')"
if   (( n >= 80 )); then cls='["critical"]'
elif (( n >= 70 )); then cls='["warning"]'
else cls='[]'
fi
printf '{"text":"\U000F02CA %d%%","class":%s,"tooltip":"Disk: %d%% used"}' "$n" "$cls" "$n"
