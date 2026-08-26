{ pkgs, ... }:

{
  # ---- NVIDIA GTX 1050 Ti: permanently powered down -------------------------
  # Per ArchWiki (XPS_15_9570 + PRIME): Pascal cards can't do fine-grained RTD3
  # power management with the proprietary driver, and the nvidia module causes
  # suspend lockups on this model. The correct move is no driver at all:
  # blacklist everything (base.nix) and let PCIe runtime PM park the card in
  # D3 (~0W). Verify after install:
  #   cat /sys/bus/pci/devices/0000:01:00.0/power/runtime_status   -> suspended
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{power/control}="auto"
  '';

  # ---- Laptop power management ----------------------------------------------
  # TLP (not power-profiles-daemon; they conflict). Defaults are sane.
  services.tlp = {
    enable = true;
    settings = {
      CPU_ENERGY_PERF_POLICY_ON_AC = "performance";
      CPU_ENERGY_PERF_POLICY_ON_BAT = "power";
      # Charge thresholds extend battery lifespan (80-85%).
      START_CHARGE_THRESH_BAT0 = 80;
      STOP_CHARGE_THRESH_BAT0 = 85;
    };
  };
  services.power-profiles-daemon.enable = false;  # conflicts with TLP

  # This machine throttles badly under load (per ArchWiki); thermald helps.
  services.thermald.enable = true;

  # Intel microcode — Spectre/Meltdown mitigations + general CPU stability.
  # Installs into initrd so patches are active from the earliest boot stage.
  hardware.cpu.intel.updateMicrocode = true;

  # ---- Undervolting (migrated from your intel-undervolt setup) ---------------
  # NixOS's services.undervolt replaces: /etc/intel-undervolt.conf edits,
  # the init.d boot script, AND manual re-apply after suspend (built-in).
  #
  # Values verified live via `sudo intel-undervolt read` on Debian (Aug 2026):
  #   effective core/cache = -130mV (old conf's CPU:-750 was inert; hardware
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
    coreOffset = -130;
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
  hardware.graphics = {
    enable = true;
    enable32Bit = true;   # 32-bit Mesa for Steam games
  };
}
