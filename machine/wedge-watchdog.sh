#!/usr/bin/env sh
# wedge-watchdog.sh — detect and repair the Intel 9260 page-scan wedge.
#
# The 9260's radio firmware can silently drop Scan_Enable to 0x00 (No Scans)
# while the kernel still believes page scan is enabled. Nothing then re-writes
# the register, so the host stops answering pages and a paired controller can
# never reconnect — pressing the controller appears to do nothing.
#
# Run on a timer as root (systemd unit wedge-watchdog.service). Each tick:
#   1. reads Scan Enable (0x03 0x0019);
#   2. if it is 0x00 and any device is paired, writes Page Scan back
#      (0x03 0x001a 0x02) and verifies the write;
#   3. logs one line per wedge episode to stdout (journald) and to
#      /var/log/wedge-watchdog.log, recording the kernel's own PSCAN belief.
#      That log is the raw material for identifying the trigger.
#
# This repairs only the *host* half. If the controller also stopped paging, a
# button press is still required — but now that press can be heard.
#
# Exit status: 0 normally (including "nothing to do"); 1 if the register was
# re-armed but would not hold, which is worth surfacing in `systemctl status`.

set -u

STATE=/run/wedge-watchdog.state		# last observed scan_enable, for edge detection
LOG=/var/log/wedge-watchdog.log		# durable record (journald may be volatile)
IFACE=hci0

log() {
	printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" | tee -a "$LOG"
}

# Read Scan Enable. Reply is "02 19 0C 00 <se>"; the 5th field is the value.
# (0x0019 is READ; 0x001a is WRITE and would return a malformed reply here.)
read_se() {
	timeout 5 hcitool cmd 0x03 0x0019 </dev/null 2>&1
}

se_val() {
	read_se | awk '$1 ~ /^[0-9a-fA-F]{2}$/ { print $5; exit }'
}

# The kernel's cached belief — the thing that goes stale and stops any re-assert.
kernel_pscan() {
	if hciconfig "$IFACE" 2>/dev/null | grep -q 'PSCAN'; then
		printf 'kernel PSCAN=on'
	else
		printf 'kernel PSCAN=off'
	fi
}

# Paired devices imply we want to be connectable (able to be paged).
has_paired() {
	timeout 5 bluetoothctl devices Paired </dev/null 2>/dev/null | grep -q '^Device '
}

# Nothing to watch if the adapter is absent or down.
hcitool dev 2>/dev/null | grep -q "$IFACE" || exit 0
hciconfig "$IFACE" 2>/dev/null | grep -q 'UP' || exit 0

SE="$(se_val)"
[ -n "$SE" ] || exit 0		# unreadable (busy/down): retry next tick

LAST="?"
[ -f "$STATE" ] && LAST="$(cat "$STATE")"

# FIN is what we record for the next run; it is the post-repair value so a
# successful repair does not look like a fresh wedge on the following tick.
FIN="$SE"
finish() {
	printf '%s\n' "$FIN" > "$STATE"
	exit "${1:-0}"
}

if [ "$SE" != "00" ]; then
	[ "$LAST" = "00" ] && log "recovered: scan_enable=0x$SE ($(kernel_pscan))"
	finish 0
fi

# scan_enable == 0x00.
if [ "$LAST" = "00" ]; then
	# Same episode as last tick, already reported: re-assert quietly.
	timeout 5 hcitool cmd 0x03 0x001a 0x02 </dev/null >/dev/null 2>&1
	finish 0
fi

if ! has_paired; then
	log "scan_enable=0x00 with no paired devices ($(kernel_pscan)) — not re-arming"
	finish 0
fi

log "WEDGE: scan_enable dropped to 0x00 ($(kernel_pscan), paired devices present) — re-arming"
timeout 5 hcitool cmd 0x03 0x001a 0x02 </dev/null >/dev/null 2>&1
SE2="$(se_val)"

if [ "$SE2" = "02" ]; then
	log "re-armed: scan_enable=0x$SE2 — controller should connect on its next page"
	FIN=02
	finish 0
fi

log "RE-ARM FAILED: scan_enable=0x${SE2:-?} — try: sudo modprobe -r btusb && sudo modprobe btusb"
FIN="?"				# force a fresh, logged attempt next tick
finish 1
