# ─────────────────────────────────────────────────────────────────────────────
# HARDWARE — machine-specific tuning for the XPS 15 9570.
#
# Everything here is tied to THIS laptop. Generic hardware enablement
# (graphics, bluetooth, fwupd) lives in modules/. Delete this file (and its
# import in flake.nix) when moving to different hardware.
# ─────────────────────────────────────────────────────────────────────────────
{ pkgs, ... }:

{
  # NVIDIA GTX 1050 Ti: permanently disabled — Pascal can't do fine-grained RTD3
  # with the proprietary driver on this model (suspend lockups). Blacklisted in
  # modules/base.nix; PCIe runtime PM parks the card (D3hot, ~0.1–0.5 W aux rail).
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{power/control}="auto"
  '';

  # This machine throttles badly under load (per ArchWiki); thermald helps.
  services.thermald.enable = true;

  # Dell thermal profile: 'performance' = aggressive fan curve, no CPU power cap.
  # May reset to 'balanced' on reboot, so re-assert on every boot (idempotent).
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

  # Undervolting — NixOS services.undervolt re-applies after suspend automatically.
  # sudo undervolt read to verify. Values tuned for THIS chip's voltage curve.
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

  # caps -> escape, kernel level (works everywhere incl. TTYs)
  services.keyd = {
    enable = true;
    keyboards.default = {
      ids = [ "*" ];
      settings.main.capslock = "escape";
    };
  };
}
