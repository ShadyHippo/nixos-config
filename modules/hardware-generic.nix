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
    powerOnBoot = false;   # battery; toggle with rfkill or bluejay
    # Force BlueZ to serve HID devices from userspace (via uhid) instead of
    # feeding the kernel's HIDP stack. Required for the disable_ertm fix below
    # to actually govern connection behaviour (writes /etc/bluetooth/input.conf).
    input.General.UserspaceHID = true;
  };

  # disable_ertm: the kernel L2CAP stack's ERTM mode is flaky with the Switch
  # Pro Controller (and several cheap dongles) — the stored link is dropped
  # seconds after connect, so the controller never reconnects reliably.
  # Module param on `bluetooth` (CONFIG_BT=m), passed over the kernel cmdline
  # so it's live from the first module load (no modprobe.d race). Equivalent
  # to `echo 1 > /sys/module/bluetooth/parameters/disable_ertm` at runtime.
  boot.kernelParams = [ "bluetooth.disable_ertm=1" ];

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
