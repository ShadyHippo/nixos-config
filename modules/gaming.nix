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

  # Games render entirely on the Intel iGPU - the 1050 Ti stays off.
  # Dolphin (GameCube/Wii) is installed user-level; see home/default.nix.
}
