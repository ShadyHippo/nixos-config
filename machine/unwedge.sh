#!/usr/bin/env sh
# unwedge.sh — rescue thewedged 9260 radio with a full rfkill power cycle.
#
# The 9260's firmware can silently drop Scan_Enable to 0x00. A plain hcitool
# write-back (0x03 0x001a 0x02) re-arms the register but was NOT consistent:
# the firmware kept dropping it again and the connect-watch sat dead. The
# thing that actually works, every time, is what Bluejay's bluetooth power
# toggle ends up doing — a full soft off→on cycle of the radio:
#
#   1. rfkill block bluetooth     (radio resets; wedged register state gone)
#   2. rfkill unblock bluetooth   (fresh start, firmware re-asserts scan)
#   3. bluetoothctl power on      (unblock restores rfkill state only)
#   4. watch for 'Connected: yes' — press the controller button!
#
# Installed as `unwedge` by machine/wedge.nix with a scoped NOPASSWD sudoers
# rule, so the $mod+BackSpace hotkey can run it without a password prompt.
#
# Usage:  sudo ./unwedge.sh [BD_ADDR]   (self-elevates if run without sudo)
# Default BD_ADDR: 20:0B:CF:34:F1:BD

set -u

ADDR="${1:-20:0B:CF:34:F1:BD}"

[ "$(id -u)" -eq 0 ] || exec sudo "$0" "$@"

echo "== unwedge: rfkill cycle ($ADDR) =="

rfkill block bluetooth
sleep 2
rfkill unblock bluetooth

echo "(not connected after 30 s — keep pressing, or run again)"
