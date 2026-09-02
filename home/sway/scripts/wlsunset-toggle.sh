#!/usr/bin/env sh
# Toggle wlsunset nightlight (constant 4000K warm). $mod+o = Orange.
# Both -t and -T set to 4000: wlsunset only applies -t (low temp) between
# sunset/sunrise; without location or manual times it defaults to a fixed
# 18:00/06:00 schedule, so -t alone is invisible during the day. -T 4000
# forces warm at all times. If running, kill it (back to normal); if not, start it.
if pgrep -x wlsunset >/dev/null 2>&1; then
  pkill wlsunset
else
  wlsunset -t 4000 -T 4000 &
fi
