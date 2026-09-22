#!/usr/bin/env sh
# problue-wire-switch.sh — toggle ProBlue's wired USB input mode.
#
# ProBlue's patched hid-nintendo makes a wired Pro Controller PASSIVE over USB
# (bind + hidraw only, no input device), so bluetoothd can cable-pair it. That
# is the default and the right thing when you want to play wirelessly.
#
# When Bluetooth jitter/latency will bother you (fighting games), flip this
# switch ON first and then plug the controller in: the driver probes it as a
# normal wired gamepad (bus=0x0003, LEDs, battery, no BT link) and bluetoothd
# logs "is in wired mode, skipping cable pairing" and stays away.
#
#   decide  ->  toggle this  ->  plug in
#
# The switch is a driver-global sysfs attribute read AT PROBE TIME, so it only
# applies to the NEXT plug. Toggling does nothing to an already-plugged
# controller; unplug and replug it. It also does not persist across reboot —
# the default after a boot is OFF (Bluetooth pairing).
#
# Installed as `problue-wire-switch` by machine/problue.nix with a scoped
# NOPASSWD sudoers rule, so the $mod+Shift+w hotkey runs without a password
# prompt. Same shape as unwedge.
#
# Usage:  sudo ./problue-wire-switch.sh   (self-elevates if run without sudo)
#         sudo ./problue-wire-switch.sh on|off   (explicit, for scripts)
#         sudo ./problue-wire-switch.sh status

set -u

ATTR=/sys/bus/hid/drivers/nintendo/wired_mode

# Self-elevate. sudo drops DBUS_SESSION_BUS_ADDRESS, which makes notify-send
# fall back to autolaunching its own bus and fail with a dbus-launch error when
# invoked from a terminal. Pass it through so toasts work either way. Only add
# the assignment when it is actually set, so we never hand sudo an empty VAR=.
if [ "$(id -u)" -ne 0 ]; then
  if [ -n "${DBUS_SESSION_BUS_ADDRESS:-}" ]; then
    exec sudo DBUS_SESSION_BUS_ADDRESS="$DBUS_SESSION_BUS_ADDRESS" "$0" "$@"
  fi
  exec sudo "$0" "$@"
fi

# Notifications are a nicety; never let one change the exit status or hide the
# wired_mode= report.
notify() {
  [ -n "${DBUS_SESSION_BUS_ADDRESS:-}" ] || return 0
  notify-send "$@" 2>/dev/null || true
}

if [ ! -w "$ATTR" ]; then
  notify -u critical "ProBlue wired mode" \
    "wired_mode attribute missing ($ATTR) — patched kernel not booted?"
  echo "error: $ATTR not present/writable; is the patched hid-nintendo running?" >&2
  echo "       (the module lives in the booted system: a rebuild needs a reboot)" >&2
  exit 1
fi

cur=$(cat "$ATTR" 2>/dev/null) || cur=""

case "${1:-toggle}" in
  on)  want=1 ;;
  off) want=0 ;;
  status)
    echo "wired_mode=$cur"
    exit 0
    ;;
  toggle)
    case "$cur" in
      1) want=0 ;;
      0) want=1 ;;
      *)
        notify -u critical "ProBlue wired mode" \
          "cannot read $ATTR (got '${cur}')"
        echo "error: unexpected value '$cur' in $ATTR" >&2
        exit 1
        ;;
    esac
    ;;
  *)
    echo "usage: $0 [toggle|on|off|status]" >&2
    exit 2
    ;;
esac

if ! echo "$want" > "$ATTR"; then
  notify -u critical "ProBlue wired mode" "failed to write $want to $ATTR"
  echo "error: write of $want to $ATTR failed" >&2
  exit 1
fi

# Read back so the notification reports what the driver actually accepted,
# not what we hoped.
now=$(cat "$ATTR")

if [ "$now" = "1" ]; then
  notify "ProBlue wired mode" "Wired USB: ON — next plug uses the cable"
else
  notify "ProBlue wired mode" "OFF — next plug pairs over Bluetooth"
fi

echo "wired_mode=$now"
[ "$now" = "$want" ] || { echo "error: driver kept '$now', wanted '$want'" >&2; exit 1; }
