{ pkgs, ... }:

{
  programs.steam = {
    enable = true;
    # Proton GE for titles the stock Proton struggles with.
    extraCompatPackages = [ pkgs.proton-ge-bin ];
  };

  programs.gamemode.enable = true;   # games request it via %command% or it just works

  # udev rules for Steam controllers / VR gear
  hardware.steam-hardware.enable = true;

  # joycond: combine two Joy-Cons into one virtual pad. Root daemon, talks to
  # BlueZ over D-Bus — starts after bluetoothd.
  systemd.services.joycond = {
    description = "Joy-Con pairing daemon";
    wantedBy = [ "multi-user.target" ];
    after = [ "bluetooth.service" ];
    serviceConfig = {
      ExecStart = "${pkgs.joycond}/bin/joycond";
      Restart = "on-failure";
      RestartSec = 5;
    };
  };

  # Games render entirely on the Intel iGPU.
}
