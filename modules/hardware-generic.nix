# ─────────────────────────────────────────────────────────────────────────────
# HARDWARE (generic) — hardware enablement that applies to any machine.
# Machine-specific tuning (undervolt, thermald, keyd) lives in machine/hardware.nix.
# ─────────────────────────────────────────────────────────────────────────────
{ config, pkgs, ... }:

{
  # Intel microcode — Spectre/Meltdown mitigations + general CPU stability.
  # Installs into initrd so patches are active from the earliest boot stage.
  hardware.cpu.intel.updateMicrocode = true;

  # Firmware updates (fwupdmgr refresh / get-updates / update).
  services.fwupd.enable = true;

  # ---- Bluetooth -------------------------------------------------------------
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;   # battery; toggle with rfkill or bluejay
    # Force BlueZ to serve HID devices from userspace (via uhid) instead of
    # feeding the kernel's HIDP stack. Required for the disable_ertm fix below
    # to actually govern connection behaviour (writes /etc/bluetooth/input.conf).
    input.General.UserspaceHID = true;
    # Nintendo's 2017 (BR/EDR) controllers memcmp the *host* device name on
    # connect. Unless it begins with "Nintendo" they fall back to a low-power
    # generic profile that leans on sniff, which costs latency and, under load,
    # packets. Prefixed with this host's name -> "Nintendo hippo-xps".
    #
    # There is no upstream fix yet, only a feature request (bluez#1797) asking
    # for a quirk; BlueZ's own answer there is to set the adapter name. Doing it
    # via main.conf means bluetoothd applies it on power-on, so it needs no
    # boot-time helper (the adapter is down at boot: powerOnBoot=false above).
    #
    # Still matches the "Nintendo" case (non-Switch profile, Active mode) and
    # deliberately does NOT match the "Nintendo Switch" case: that one switches
    # the controller to its native 0x3F report format, whereas hid_nintendo
    # explicitly requests 0x30 (JC_SUBCMD_SET_REPORT_MODE).
    settings.General.Name = "Nintendo ${config.networking.hostName}";
  };

  # disable_ertm: the kernel L2CAP stack's ERTM mode is flaky with the Switch
  # Pro Controller (and several cheap dongles) — the stored link is dropped
  # seconds after connect, so the controller never reconnects reliably.
  # Module param on `bluetooth` (CONFIG_BT=m), passed over the kernel cmdline
  # so it's live from the first module load (no modprobe.d race). Equivalent
  # to `echo 1 > /sys/module/bluetooth/parameters/disable_ertm` at runtime.
  # btusb.enable_autosuspend=0: keep the 9260's USB link out of runtime
  # suspend. With autosuspend on (module default), the link parks 2 s after
  # idleness and the radio can silently lose its Scan_Enable register while
  # the kernel's cached HCI_PSCAN flag still reads "on" — hci_update_scan_sync
  # then skips re-asserting it (hci_sync.c), so the host stops answering pages
  # and paired devices can't reconnect until a full power cycle. Cost is tens
  # of mW on the USB link; the radio's own low-power scan duty cycling is
  # firmware-managed and unaffected, and system sleep suspends the device
  # regardless. Wi-Fi is PCIe/iwlwifi — untouched by this.
  boot.kernelParams = [ "bluetooth.disable_ertm=1" "btusb.enable_autosuspend=0" ];

  # The kernel param alone is not sufficient: the device still ends up with
  # control=auto and runtime-suspends (verified live). Pin the device node
  # directly; "on" = pm_runtime_forbid, the link stays in L0 while awake.
  services.udev.extraRules = ''
    ACTION=="add|change", SUBSYSTEM=="usb", ATTR{idVendor}=="8087", ATTR{idProduct}=="0025", ATTR{power/control}="on"
  '';

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
