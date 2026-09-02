#!/usr/bin/env sh
# Toggle wlsunset nightlight (constant warm). $mod+o = Orange.
# wlsunset REQUIRES -T (high) > -t (low) — equal temps exit rc=1 with
# "high temp must be higher than low temp", invisible when launched with &
# from sway. So -t 4000 -T 4001: daytime outputs 4001K, night 4000K — both
# warm, 1K apart = imperceptible, constant warm whenever ON. (Without -l/-L
# or -S/-s it uses a fixed 18:00/06:00 schedule; irrelevant now that both
# temps are ~4000.) If running, kill it (back to normal); if not, start it.
if pgrep -x wlsunset >/dev/null 2>&1; then
  pkill wlsunset
else
  wlsunset -t 4000 -T 4001 &
fi
