{ ... }:

{
  imports = [
    ./hardware-configuration.nix   # generated at install time (UUIDs live there)
    ./modules/base.nix             # boot, nix, locale, users, ssh
    ./modules/hardware.nix         # dGPU kill switch, TLP, bluetooth, keyd
    ./modules/audio.nix            # PipeWire
    ./modules/desktop.nix          # Sway, greetd, portals, fonts, HiDPI
    ./modules/gaming.nix           # Steam, Proton, GameMode
    ./modules/dev.nix              # Docker (agent sandboxing), nix-ld
    ./modules/apps.nix             # app poll results + printing/scanning/tailscale
  ];
}
