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
#   1. `unwedge` — manual rescue, bound to $mod+BackSpace (home/sway/config).
#      Reads 0x03 0x0019, writes 0x03 0x001a 0x02, re-reads, then watches for a
#      reconnect. Runs as root via a scoped NOPASSWD rule.
#   2. `wedge-watchdog` — a systemd timer that detects the wedge and re-arms the
#      register by itself, so the hotkey becomes the fallback rather than the
#      only mechanism. Each episode is logged (journald + /var/log/
#      wedge-watchdog.log) with the kernel's own PSCAN belief, to eventually
#      identify the trigger.
#
# Firmware is already current (ibt-18-16-1.sfi build 201-12.24 == the
# linux-firmware-20260810 blob) and the 2025 update was reverted upstream
# (linux-bluetooth bug 220306), so there is no upgrade path; a host-side repair
# is the only option. The trigger (PTT/WiFi coexistence, suspend/resume, or an
# idle transition) is still unknown — see the watchdog log.
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
    pkgs.gawk
    pkgs.gnugrep
  ];

  unwedge = pkgs.writeShellScriptBin "unwedge" (''
    export PATH="${hciPath}:$PATH"
  '' + builtins.readFile ./unwedge.sh);

  wedge-watchdog = pkgs.writeShellScriptBin "wedge-watchdog" (''
    export PATH="${hciPath}:$PATH"
  '' + builtins.readFile ./wedge-watchdog.sh);
in
{
  environment.systemPackages = [ unwedge ];

  # NOPASSWD scoped to this one script — the hotkey runs without a terminal to
  # prompt on, so it cannot answer a password prompt. Both the store path and
  # the system path are listed so it works whether invoked via PATH or directly.
  # (A rule for the ~/.config symlink would be refused: user-owned path.)
  # The watchdog needs no sudoers rule — it runs as root.
  security.sudo.extraRules = [{
    users = [ "hippo" ];
    commands = [
      { command = "${unwedge}/bin/unwedge"; options = [ "NOPASSWD" ]; }
      { command = "/run/current-system/sw/bin/unwedge"; options = [ "NOPASSWD" ]; }
    ];
  }];

  systemd.services.wedge-watchdog = {
    description = "Re-arm the 9260 page-scan register if the radio silently dropped it";
    after = [ "bluetooth.service" ];
    wants = [ "bluetooth.service" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${wedge-watchdog}/bin/wedge-watchdog";
    };
  };

  systemd.timers.wedge-watchdog = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      # Wait for boot to settle before the first probe, then poll steadily.
      # One HCI read per tick is cheap; the script exits immediately when the
      # adapter is down or Scan Enable is healthy.
      OnBootSec = "2min";
      OnUnitActiveSec = "10s";
      AccuracySec = "1s";
    };
  };
}
