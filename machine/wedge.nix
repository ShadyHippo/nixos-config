# ─────────────────────────────────────────────────────────────────────────────
# Intel Wireless-AC 9260 — Bluetooth page-scan wedge (machine-specific).
#
# Nothing to do with ProBlue; it lives here because it is a property of THIS
# machine's radio and can be mistaken for a pairing failure.
#
# The 9260's radio firmware can silently drop Scan_Enable to 0x00 (No Scans)
# while the kernel still believes page scan is enabled. Nothing re-writes the
# register, so the host stops answering pages and a paired controller can never
# reconnect — pressing it appears to do nothing. Two pieces:
#
#   `unwedge` — manual rescue, bound to $mod+BackSpace (home/sway/config).
#   Does what Bluejay's power toggle effectively does: a full rfkill off→on
#   cycle of the radio. The firmware reset re-asserts Scan_Enable, which the
#   plain hcitool write-back (0x03 0x001a 0x02) could NOT keep re-applied —
#   the firmware dropped it again. The hard cycle is the only consistent fix.
#   The old wedge-watchdog.service/timer (which polled Scan_Enable every 10 s)
#   was removed 2026-09-15: the rfkill cycle works, the register probing did
#   not detect-and-heal reliably.
#
# Firmware is already current (ibt-18-16-1.sfi build 201-12.24 == the
# linux-firmware-20260810 blob) and the 2025 update was reverted upstream
# (linux-bluetooth bug 220306), so there is no upgrade path; a host-side repair
# is the only option. The trigger (PTT/WiFi coexistence, suspend/resume, or an
# idle transition) is still unknown.
#
# Also dropped 2026-09-12 (boot-freeze bisection): the btusb remote-wake v2
# patch, since deleted, plus btusb.enable_autosuspend=0 / iwlwifi.bt_coex_active=0
# together hard-froze this laptop ~3s into boot during udev coldplug (black
# screen, journal stops, NMI watchdog silent). Suspect: patched btusb calling
# usb_acpi_power_manageable() into the broken XHC.RHUB ACPI namespace (the 96
# AE_ALREADY_EXISTS wall) and/or the coex param. Re-add ONE variable at a time.
#
# Delete this file (and its import in flake.nix) on machines without the 9260.
# ─────────────────────────────────────────────────────────────────────────────
{ pkgs, ... }:

let
  # Raw HCI access comes from bluez's hcitool/hciconfig; the rest is text tools.
  hciPath = pkgs.lib.makeBinPath [
    pkgs.bluez
    pkgs.coreutils
    pkgs.gnugrep
    pkgs.util-linux
  ];

  unwedge = pkgs.writeShellScriptBin "unwedge" (''
    export PATH="${hciPath}:$PATH"
  '' + builtins.readFile ./unwedge.sh);
in
{
  environment.systemPackages = [ unwedge ];

  # NOPASSWD scoped to this one script — the hotkey runs without a terminal to
  # prompt on, so it cannot answer a password prompt. Both the store path and
  # the system path are listed so it works whether invoked via PATH or directly.
  # (A rule for the ~/.config symlink would be refused: user-owned path.)
  security.sudo.extraRules = [{
    users = [ "hippo" ];
    commands = [
      { command = "${unwedge}/bin/unwedge"; options = [ "NOPASSWD" ]; }
      { command = "/run/current-system/sw/bin/unwedge"; options = [ "NOPASSWD" ]; }
    ];
  }];

}

