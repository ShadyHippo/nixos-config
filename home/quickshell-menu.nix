# The quickshell game-launcher menu (home/quickshell/shell.qml →
# ~/.config/quickshell/shell.qml, run by the `quickshell.service` systemd user
# unit below, toggled with $mod+g).
#
# It is a SERVICE, not a sway autostart: `exec qs -n` only fires once at sway
# startup, so any exit (crash, `qs kill`, a bad reload) left it dead for the
# rest of the session — which is exactly what kept happening. The unit
# restarts on any exit, and is tied to `graphical-session.target` so it comes
# up/stops with the session. It also re-reads the menu on rebuild
# (X-Restart-Triggers, below).
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

  # Substituted ONCE, then used for two things: the deployed default config and
  # the unit's X-Restart-Triggers. Keeping it a single derivation is what makes
  # the rebuild-reload trigger exact and proves the file on disk and the file
  # the service is tied to are byte-identical.
  shellQml = pkgs.writeText "quickshell-shell.qml" (
    tokens "quickshell/shell.qml" {
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
    } (builtins.readFile ./quickshell/shell.qml)
  );
in
{
  home.sessionVariables = {
    QS_GAMEPAD_IPC_TARGET    = gamepadIpcTarget;
    QS_GAMEPAD_HOME_FUNCTION = gamepadHomeFunction;
  };

  # Default config path — what a hand-run bare `qs` and `qs ipc call menu …`
  # resolve to. The unit runs quickshell with no -p/-c so it loads THIS path,
  # which is why the sway $mod+g bind stays a plain `qs ipc call menu toggle`.
  xdg.configFile."quickshell/shell.qml".source = shellQml;

  systemd.user.services.quickshell = {
    Unit = {
      Description = "Quickshell game launcher menu (quickshell#1189 gamepad patch)";
      # Same target as the other session daemons (easyeffects). The NixOS sway
      # wrapper has already imported WAYLAND_DISPLAY / XDG_RUNTIME_DIR /
      # SWAYSOCK into the user manager by the time this target is reached.
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
      # Rebuild-reload trigger. sd-switch restarts the unit when one of these
      # paths changes during Home Manager activation. shellQml's store path
      # changes iff the QML (or any token it embeds, e.g. a package path)
      # changes — so a rebuild swaps in the new menu instead of leaving the old
      # one loaded until a manual restart.
      X-Restart-Triggers = [ shellQml ];
    };
    Service = {
      # Drop a stray instance first so -n can't bounce us into a restart loop
      # (e.g. one left over from a hand-run `qs` before the switch). '-' keeps
      # the "no running instances" non-zero exit from failing the start.
      ExecStartPre = "-${pkgs.quickshell}/bin/quickshell kill";
      ExecStart = "${pkgs.quickshell}/bin/quickshell -n";
      # Return after ANY exit, clean or not — the whole point of the unit.
      # (`qs kill` no longer sticks; use `systemctl --user stop quickshell`.)
      Restart = "always";
      RestartSec = 1;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
