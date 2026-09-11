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

  # Keep the Intel Wireless-AC 9260 Bluetooth adapter (USB 8087:0025) out of
  # USB autosuspend. Observed 2026-09-11: while the radio is runtime-suspended
  # the Pro Controller's reconnect pages go unheard (host reads PSCAN/healthy,
  # btmon sees nothing, only an adapter power cycle restores it). Test subject:
  # "problue" reconnect wedge — see V2 docs. Remove the rule if pinning the
  # device awake does not stop the wedge.
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="8087", ATTR{idProduct}=="0025", \
      TEST=="power/control", ATTR{power/control}="on"
  '';

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
