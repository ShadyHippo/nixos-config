# ─────────────────────────────────────────────────────────────────────────────
# PRINTING — Brother MFC-J6555DW network printer + scanner.
#
# brlaser is mono-laser-only and does NOT work with inkjets — hence the
# brgenml1 drivers. Verify after rebuild: scanimage -L
# ─────────────────────────────────────────────────────────────────────────────
{ pkgs, ... }:

{
  services.printing = {
    enable = true;
    drivers = [
      pkgs.brgenml1lpr
      pkgs.brgenml1cupswrapper
    ];
  };

  # SCAN: brscan5 SANE backend. Scanner reached over LAN.
  hardware.sane = {
    enable = true;
    brscan5.enable = true;
    brscan5.netDevices = {
      # MFC-J6555DW = { model = "MFC-J6555DW"; ip = "192.168.1.50"; };
      #   -- or --  MFC-J6555DW = { model = "MFC-J6555DW"; nodename = "BRW000000000000"; };
    };
  };

  # Scan + print GUIs
  environment.systemPackages = with pkgs; [
    system-config-printer    # CUPS admin GUI
    simple-scan              # scanner GUI
  ];

  # mDNS so CUPS/avahi discover the printer on the LAN. nssmdns4 also lets
  # plain tools resolve the printer's .local name (ping/ssh BRW....local).
  services.avahi = {
    enable = true;
    nssmdns4 = true;
  };
}
