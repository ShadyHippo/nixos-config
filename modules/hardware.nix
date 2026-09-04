{ pkgs, ... }:

{
  # ---- NVIDIA GTX 1050 Ti: permanently disabled (no driver, no USE) ----------
  # Per ArchWiki (XPS_15_9570 + PRIME): Pascal cards can't do fine-grained RTD3
  # with the proprietary driver, and the nvidia module causes suspend lockups
  # on this model. So: no driver at all (blacklisted + install /bin/false in
  # base.nix) and let PCIe runtime PM park the card.
  #
  # HONEST POWER STATE (verified live 2026-08-31): the card is D3hot, NOT
  # D3cold. `0000:01:00.0/power/runtime_status` = suspended and the runtime
  # counters tick up stably, BUT its config space still reads the real device
  # ID (10de:1c8d) instead of all-0xFF — the signature of D3hot. D3hot still
  # draws the 3.3V aux rail (order ~0.1–0.5 W), so it is NOT truly zero-power.
  # It is only D3hot because the upstream bridge is Intel 8086:1901, which trips
  # the kernel `quirk_broken_nv_runpm` fix: Pascal GPUs behind this bridge can't
  # be guaranteed to return from D3cold→D0 (the device vanishes from the bus).
  # Forcing D3cold (acpi_rev_override / pcie_port_pm=on) would risk that resume
  # failure. Leaving D3hot is the safe, correct choice. The user must know:
  # "fully disabled" = yes; "zero-power" = not physically achievable here.
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{power/control}="auto"
  '';

  # ---- Laptop power management ----------------------------------------------
  # TLP dropped (2026 Q3): kernel 6.x + intel_pstate already handles CPU freq,
  # TLP's raw tunables are largely redundant, and power-profiles-daemon is
  # GNOME/KDE-oriented (not sway). We rely on the intel_pstate powersave
  # governor (active) + thermald below. Battery charges to 100%: the 85/80 EC
  # cap (written by the old TLP setup) was lifted by writing the EC directly;
  # it persists in hardware and nothing in this config writes it back.

  # This machine throttles badly under load (per ArchWiki); thermald helps.
  services.thermald.enable = true;

  # ---- Dell thermal profile: "performance" ----------------------------------
  # Kernel 6.x exposes Dell Power Manager's thermal modes (cool/quiet/balanced/
  # performance) via /sys/firmware/acpi/platform_profile. `performance` is the
  # EC's most aggressive fan curve; unlike `quiet`/`cool` it does NOT cap CPU
  # power. Verified live 2026-09-03 on BIOS 1.31.0. The firmware may boot back
  # into `balanced`, so re-assert it on every boot (idempotent write).
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

  # ---- Undervolting (migrated from your intel-undervolt setup) ---------------
  # NixOS's services.undervolt replaces: /etc/intel-undervolt.conf edits,
  # the init.d boot script, AND manual re-apply after suspend (built-in).
  #
  # Values verified live via `sudo intel-undervolt read` on Debian (Aug 2026):
  #   effective core/cache = -150mV (old conf's CPU:-750 was inert; hardware
  #   applies the LESS-negative of core/cache), GPU = -150mV.
  # Power limits match your old config exactly: 45W burst / 35W sustained.
  #
  # CORE AND CACHE ARE ONE KNOB: the CPU takes the less-negative of the two,
  # so the module only exposes coreOffset (matches Intel's documented behavior).
  #
  # BIOS INTERACTION: running BIOS 1.31.0 (>1.16) and undervolting works -
  # this unit ignores the Plundervolt lock. fwupd below can flash newer
  # firmware; if an update ever lands and voltages stop holding, check here:
  #   sudo undervolt read
  services.undervolt = {
    enable = true;
    coreOffset = -150;
    gpuOffset = -150;
    p1.limit = 35;       # sustained (PL1)
    p1.window = 28;
    p2.limit = 45;       # burst (PL2)
    p2.window = 0.002;
    useTimer = false;    # boot + sleep re-apply covers it; flip true if drift
  };

  # ---- Firmware updates (fwupd, from your notes) -----------------------------
  # fwupdmgr refresh / get-updates / update work out of the box.
  # See the BIOS caveat above before updating firmware.
  services.fwupd.enable = true;

  # ---- Bluetooth -------------------------------------------------------------
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = false;   # battery; toggle with rfkill or blueman
  };

  # ---- Nintendo Switch controllers (Joy-Con / Pro) ---------------------------
  # hid_nintendo: kernel's native driver for Switch controllers over USB/BT.
  # Merges with hardware-configuration.nix's kvm-intel via list concatenation.
  boot.kernelModules = [ "hid_nintendo" ];

  # ---- Wi-Fi/BT (Intel AC 9560 — replaced the stock QCA6174) ----------------
  # Intel iwlwifi driver is mature and in-kernel, but the firmware blob is
  # non-free-redistributable. Without this option the card has no firmware
  # and Wi-Fi won't work at all on first boot.
  hardware.enableRedistributableFirmware = true;

  # ---- caps -> escape, kernel level (works everywhere incl. TTYs) ------------
  services.keyd = {
    enable = true;
    keyboards.default = {
      ids = [ "*" ];
      settings.main.capslock = "escape";   # same as your current /etc/keyd/default.conf
    };
  };

  # ---- GPU acceleration (Intel UHD 630 is the only active GPU) ---------------
  # `hardware.graphics.enable` already installs pkgs.mesa, which ships the Intel
  # "ANV" Vulkan driver by default (vulkanDrivers includes "intel"), so
  # Chromium/Firefox/WebGL get hardware Vulkan with nothing extra to add. There
  # is NO separate `vulkan-intel` package on this nixpkgs branch; it's part of
  # mesa. We deliberately DO NOT add libva-intel-driver (legacy i965): on the 8th
  # gen Coffeelake the modern intel-media-driver (iHD) fully covers the UHD 630.
  hardware.graphics = {
    enable = true;
    enable32Bit = true;   # 32-bit Mesa for Steam games
    extraPackages = [
      pkgs.intel-media-driver   # VAAPI (iHD) — correct for UHD 630
    ];
  };

  # System packages. VAAPI/Vulkan drivers go through extraPackages into
  # /run/opengl-driver (NOT on PATH), so CLI tools live here instead.
  environment.systemPackages = [
    pkgs.libva-utils      # `vainfo` — confirm VAAPI decode is wired up
    pkgs.intel-gpu-tools  # `intel_gpu_top` — live iGPU utilisation/freq
  ];
}
