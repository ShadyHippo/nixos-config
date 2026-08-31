#!/usr/bin/env sh
# Toggle wlsunset nightlight (~4000K warm). $mod+Shift+u.
# If running, kill it (back to normal); if not, start it.
if pgrep -x wlsunset >/dev/null 2>&1; then
  pkill wlsunset
else
  wlsunset -t 4000 &
fi
