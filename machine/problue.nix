# ─────────────────────────────────────────────────────────────────────────────
# PROBLUE — Switch Pro Controller wired cable pairing (machine-specific).
#
# Port of V1's cable-pairing. Adds, for THIS machine:
#   1. kernel `hid_nintendo` passive over USB (bluetoothd owns the hidraw)
#   2. BlueZ 5.86 with the procon plugin (wired pairing / link-key storage)
#
# (Dropped 2026-09-12, boot-freeze bisection: the Intel 9260 experiments —
# btusb-remote-wake v2 kernel patch + btusb.enable_autosuspend=0 /
# iwlwifi.bt_coex_active=0 params — hard-freeze this laptop ~3s into boot
# during udev coldplug (black screen, journal stops, NMI watchdog silent).
# Suspect: patched btusb calling usb_acpi_power_manageable() into the broken
# XHC.RHUB ACPI namespace (the 96 AE_ALREADY_EXISTS wall) and/or the coex
# param. Re-add ONE variable at a time to bisect after ProBlue boots.
#
# Patches live in ../patches/ (tracked in git) and target kernel 6.18.46 +
# BlueZ 5.86 — the nixos-26.05 pin defaults (verified: `nix eval` → 6.18.46 /
# 5.86). If the kernel series or bluez version ever changes, re-base these
# patches; the build fails loudly if they stop applying.
#
# Delete this file (and its import in flake.nix) on machines without the
# Switch Pro Controller wiring.
# ─────────────────────────────────────────────────────────────────────────────
{ pkgs, ... }:

{
  # ---- 1. Kernel patches ------------------------------------------------------
  boot.kernelPatches = [
    # ProBlue stage 3: hid-nintendo is passive on USB so bluetoothd's procon
    # plugin is the only writer on the controller's hidraw. BT path is stock.
    {
      name = "problue-hid-nintendo-passive";
      patch = ../patches/problue-hid-nintendo-passive-6.18.46.patch;
    }
  ];

  # ---- 2. BlueZ: procon cable-pairing plugin ----------------------------------
  # Stock BlueZ 5.86 + the stage-5 patch (profiles/input/procon.{c,h}, sixaxis
  # wiring, key storage). Appends to the upstream patch list rather than
  # replacing it. UserspaceHID + powerOnBoot are already set in
  # modules/hardware-generic.nix and are not duplicated here.
  hardware.bluetooth.package = pkgs.bluez.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [ ../patches/problue-bluez-procon-5.86.patch ];
  });
}