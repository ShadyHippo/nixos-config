# The quickshell game-launcher menu (home/quickshell/shell.qml →
# ~/.config/quickshell/shell.qml, autostarted by sway as `qs -n`, toggled with
# $mod+g). HM symlinks the file into the store, so qs hot-reload can't see
# across rebuilds — restart `qs` after switching.
#
# GAMEPAD COUPLING — single source of truth: the locally patched quickshell
# reads gamepad input from evdev and dispatches it to an IpcHandler it finds by
# NAME (target), calling the Home function by NAME. Both names are defined in
# the lets below and wired to BOTH consumers from here:
#   - the QML, via the @GAMEPAD_*@ tokens
#   - the patched binary, via the QS_GAMEPAD_* env vars (its built-in defaults
#     "menu"/"toggle" are only a fallback — nothing may rely on them)
# Renaming the handler is a one-line change here; the leftover-token check in
# lib/tokens.nix fails the build if the QML template and this attrset drift.
{ pkgs, config, ... }:

let
  theme = import ../machine/theme.nix;
  pal   = theme.palette;
  tokens = import ../lib/tokens.nix;

  gamepadIpcTarget    = "menu";   # the IpcHandler target in shell.qml
  gamepadHomeFunction = "toggle"; # the IpcHandler function Home dispatches
in
{
  home.sessionVariables = {
    QS_GAMEPAD_IPC_TARGET    = gamepadIpcTarget;
    QS_GAMEPAD_HOME_FUNCTION = gamepadHomeFunction;
  };

  xdg.configFile."quickshell/shell.qml".text = tokens "quickshell/shell.qml" {
    PAL_BG = pal.bg; PAL_BGALT = pal.bgAlt; PAL_BGDIM = pal.bgDim;
    PAL_FG = pal.fg; PAL_FGDIM = pal.fgDim;
    PAL_ACCENT = pal.accent;
    FONT = theme.font.family;
    ICON_RETRODECK = "${../images/retrodeck.svg}";
    ICON_MOONLIGHT = "${../images/moonlight.svg}";
    ICON_STEAM = "${../images/steam.svg}";
    ICON_JELLYFIN = "${../images/jellyfin.svg}";
    BIN_FLATPAK = "${pkgs.flatpak}/bin/flatpak";
    BIN_MOONLIGHT = "${pkgs.moonlight-qt}/bin/moonlight";
    BIN_STEAM = "${pkgs.steam}/bin/steam";
    BIN_JELLYFIN = "${pkgs.jellyfin-desktop}/bin/jellyfin-desktop";
    BIN_SH = "${pkgs.bash}/bin/bash";
    SET_RES = "${config.home.homeDirectory}/.config/sway/scripts/set-res.sh";
    BIN_SWAYMSG = "${pkgs.sway}/bin/swaymsg";
    WS_CLEAN = "${config.home.homeDirectory}/.config/sway/scripts/ws-clean.sh";
    WS_LIST = "${config.home.homeDirectory}/.config/sway/scripts/ws-list.sh";
    BIN_SWAYOSD = "${pkgs.swayosd}/bin/swayosd-client";
    BIN_PLAYERCTL = "${pkgs.playerctl}/bin/playerctl";
    GAMEPAD_IPC_TARGET = gamepadIpcTarget;
    GAMEPAD_HOME_FUNCTION = gamepadHomeFunction;
  } (builtins.readFile ./quickshell/shell.qml);
}
