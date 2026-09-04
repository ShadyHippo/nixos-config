{ pkgs, ... }:

{
  # NVIDIA GTX 1050 Ti: permanently disabled — Pascal can't do fine-grained RTD3
  # with the proprietary driver on this model (suspend lockups). Blacklisted in
  # base.nix; PCIe runtime PM parks the card (D3hot, ~0.1–0.5 W aux rail).
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{power/control}="auto"
  '';

  # Laptop power: kernel 6.x intel_pstate handles CPU freq governor; thermald
  # below handles thermal throttling. No TLP (sway has no power-profiles-daemon).

  # This machine throttles badly under load (per ArchWiki); thermald helps.
  services.thermald.enable = true;

  # Dell thermal profile: 'performance' = aggressive fan curve, no CPU power cap.
  # Kernel 6.x exposes this via /sys/firmware/acpi/platform_profile. May reset
  # to 'balanced' on reboot, so re-assert on every boot (idempotent).
  systemd.services.dell-fan-performance = {
    wantedBy = [ "multi-user.target" ];
    after = [ "multi-user.target" ];
    serviceConfig.Type = "oneshot";
    script = ''
      for i in $(seq 1 20); do
        [ -e /sys/firmware/acpi/platform_profile ] && break
        sleep 0.5
      done
      echo performance > /sys/firmware/acpi/platform_profile
    '';
  };

  # Intel microcode — Spectre/Meltdown mitigations + general CPU stability.
  # Installs into initrd so patches are active from the earliest boot stage.
  hardware.cpu.intel.updateMicrocode = true;

  # Undervolting — NixOS services.undervolt re-applies after suspend automatically.
  # sudo undervolt read to verify.
  services.undervolt = {
    enable = true;
    coreOffset = -160;
    gpuOffset = -160;
    p1.limit = 35;       # sustained (PL1)
    p1.window = 28;
    p2.limit = 45;       # burst (PL2)
    p2.window = 0.002;
    useTimer = false;    # boot + sleep re-apply covers it; flip true if drift
  };

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

  # Intel Wi-Fi/BT (AC 9560): iwlwifi is in-kernel but needs the non-free
  # firmware blob. Without this, Wi-Fi won't work on first boot.
  hardware.enableRedistributableFirmware = true;

  # ---- caps -> escape, kernel level (works everywhere incl. TTYs) ------------
  services.keyd = {
    enable = true;
    keyboards.default = {
      ids = [ "*" ];
      settings.main.capslock = "escape";   # same as your current /etc/keyd/default.conf
    };
  };

  # GPU acceleration (Intel UHD 630): hardware.graphics.enable installs Mesa
  # (includes ANV Vulkan driver + iHD VAAPI). No separate vulkan-intel package.
  hardware.graphics = {
    enable = true;
    enable32Bit = true;   # 32-bit Mesa for Steam games
    extraPackages = [
      pkgs.intel-media-driver   # VAAPI (iHD) — correct for UHD 630
    ];
  };

  # System packages — VAAPI/Vulkan drivers go through extraPackages into
  # /run/opengl-driver (not on PATH), so CLI tools live here.
  environment.systemPackages = [
    pkgs.libva-utils      # `vainfo` — confirm VAAPI decode is wired up
    pkgs.intel-gpu-tools  # `intel_gpu_top` — live iGPU utilisation/freq
  ];
}
