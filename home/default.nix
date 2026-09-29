# Home-manager hub — one import per concern, see each file's header.
# machine-specific imports (resolution.nix, gtk4-*.nix) and every value they
# consume are called out in the README's machine/ table; nothing outside
# machine/ is machine-tuned.
{ ... }:

let
  identity = import ../machine/identity.nix;
in
{
  home.username = identity.username;
  home.stateVersion = "26.05";

  imports = [
    ./packages.nix        # user packages, desktop-entry overrides, mime, flatpak
    ./env.nix             # session env vars (cursor, SDL gamepad mapping)
    ./shell.nix           # zsh/fzf/mise/git/gh + ghostty
    ./session.nix         # sway + kanshi + session scripts + resolution presets
    ./waybar.nix          # bar (config substituted via lib/tokens.nix)
    ./quickshell-menu.nix # game launcher menu + gamepad IPC name coupling
    ./theming.nix         # GTK/Qt/KDE/cursor theming
  ];
}
