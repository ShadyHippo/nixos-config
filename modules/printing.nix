{ pkgs, ... }:

{
  # ---- Brother MFC-J6555DW — network print + scan ----------------------------
  # PRINT: generic Brother driver (brgenml1lpr + cupswrapper) covers this
  # inkjet. NOTE: brlaser is MONO-LASER-ONLY and does NOT work with inkjets —
  # don't add it "for good measure".
  services.printing = {
    enable = true;
    drivers = [
      pkgs.brgenml1lpr
      pkgs.brgenml1cupswrapper
    ];
  };

  # SCAN: brscan5 SANE backend + the network device. The scanner is reached
  # over the LAN, so register it in netDevices (ip OR nodename = BRW<MAC>).
  # Verify after rebuild with: scanimage -L
  hardware.sane = {
    enable = true;
    brscan5.enable = true;
    brscan5.netDevices = {
      # MFC-J6555DW = { model = "MFC-J6555DW"; ip = "192.168.1.50"; };
      #   -- or --  MFC-J6555DW = { model = "MFC-J6555DW"; nodename = "BRW000000000000"; };
    };
  };

  # Scan + print GUIs (sway desktop): printer admin and scanner frontends.
  environment.systemPackages = with pkgs; [
    system-config-printer    # CUPS admin GUI (add/configure printers)
    simple-scan              # scanner GUI
  ];

  # mDNS so CUPS/avahi discover the printer on the LAN; also lets us resolve
  # its address as `<hostname>.local`.
  services.avahi.enable = true;
}