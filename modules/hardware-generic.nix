# ─────────────────────────────────────────────────────────────────────────────
# HARDWARE (generic) — hardware enablement that applies to any machine.
# Machine-specific tuning (undervolt, thermald, keyd) lives in machine/hardware.nix.
# ─────────────────────────────────────────────────────────────────────────────
{ pkgs, ... }:

{
  # Intel microcode — Spectre/Meltdown mitigations + general CPU stability.
  # Installs into initrd so patches are active from the earliest boot stage.
  hardware.cpu.intel.updateMicrocode = true;

  # Firmware updates (fwupdmgr refresh / get-updates / update).
  services.fwupd.enable = true;

  # ---- Bluetooth -------------------------------------------------------------
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = false;   # battery; toggle with rfkill or blueman
  };

  # ---- Nintendo Switch controllers (Joy-Con / Pro) ---------------------------
  # hid_nintendo: kernel's native driver for Switch controllers.
  boot.kernelModules = [ "hid_nintendo" ];

  # Wi-Fi/Bluetooth non-free firmware blobs.
  hardware.enableRedistributableFirmware = true;

  # GPU acceleration (Intel): hardware.graphics.enable installs Mesa
  # (includes ANV Vulkan driver + iHD VAAPI). No separate vulkan-intel package.
  hardware.graphics = {
    enable = true;
    enable32Bit = true;   # 32-bit Mesa for Steam games
    extraPackages = [
      pkgs.intel-media-driver   # VAAPI (iHD)
    ];
  };

  # System packages — VAAPI/Vulkan drivers go through extraPackages into
  # /run/opengl-driver (not on PATH), so CLI tools live here.
  environment.systemPackages = [
    pkgs.libva-utils      # `vainfo` — confirm VAAPI decode is wired up
    pkgs.intel-gpu-tools  # `intel_gpu_top` — live iGPU utilisation/freq
  ];
}
