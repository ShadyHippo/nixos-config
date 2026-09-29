# Sway session: window manager, kanshi, fuzzel/mako/swayosd styling, and every
# session script sway/waybar exec. Resolution presets ($mod+F10/11/12) come from
# machine/resolution.nix (a script generator — delete whole, never edit).
{ ... }:

let
  theme = import ../machine/theme.nix;
  pal   = theme.palette;
in
{
  # resolution.nix is a `theme: → module` script generator, not a plain module
  # — call it with the theme explicitly.
  imports = [ (import ../machine/resolution.nix theme) ];

  # ---------------------------------------------------------------------------
  # Sway — home/sway/config holds the static config (keybindings, rules,
  # autostart). The dynamic values below are appended via extraConfig from
  # machine/theme.nix (sway applies last-wins, so appending overrides cleanly).
  # ---------------------------------------------------------------------------
  wayland.windowManager.sway = {
    enable = true;
    config = null;
    # checkConfig runs `sway -C` on the generated file at BUILD time. It was
    # disabled because the wallpaper only existed after activation (the check
    # verifies the bg file); the bg line below now points at the store copy of
    # the image — a build input — so the check runs for real again and syntax
    # errors fail the build instead of surfacing as a failed `swaymsg reload`.
    checkConfig = true;
    extraConfig = let
      pavu = theme.popups.pavucontrol;
      blu  = theme.popups.bluejay;
    in
      (builtins.readFile ./sway/config) + ''
      # ── Dynamic values from machine/theme.nix (appended: last-wins) ──
      font ${theme.font.family} ${toString theme.font.points.sway}
      seat * xcursor_theme ${theme.cursorTheme} ${toString theme.display.cursor.seat}
      # Wallpaper straight from the Nix store (present at build time for
      # checkConfig, stable at runtime). The old ~/.local/share/backgrounds
      # copy existed only so this line could avoid a store path.
      output eDP-1 bg ${../images/gruvbox_astronaut-4k.png} fill
      titlebar_padding ${toString theme.titlebarPadding}

      client.focused          ${pal.blue} ${pal.blue} ${pal.bg}
      client.focused_inactive ${pal.bgDim} ${pal.bgDim} ${pal.fg}
      client.unfocused        ${pal.bgAlt} ${pal.bgAlt} ${pal.fgDim}
      client.urgent           ${pal.red} ${pal.red} ${pal.fg}

      # Floating popup anchors (from theme.nix popups)
      for_window [app_id="(?i)pavucontrol"] move position ${toString pavu.x} ${toString pavu.y}
      for_window [class="(?i)pavucontrol"] move position ${toString pavu.x} ${toString pavu.y}
      # bluejay: Qt6 native Wayland — no X11 class, app_id only.
      for_window [app_id="(?i)io.github.ebonjaeger.bluejay"] resize set ${toString blu.w} ${toString blu.h}
      for_window [app_id="(?i)io.github.ebonjaeger.bluejay"] move position ${toString blu.x} ${toString blu.y}

      # Auto-float XWayland dialogs/popups. NOTE: window_role/window_type are
      # X11-only criteria (man 5 sway); native Wayland windows (e.g. Dolphin's
      # file-transfer/confirm dialogs) are handled by app_id/title rules in
      # sway/config instead.
      for_window [window_role="pop-up"] floating enable
      for_window [window_role="dialog"] floating enable
    '';
  };

  # force: set-res.sh rewrites at runtime; must not back up (stale .bak).
  xdg.configFile."sway/config".force = true;

  # Fuzzel launcher — gruvbox theme (plain file copy, no token substitution).
  xdg.configFile."fuzzel/fuzzel.ini".source = ./fuzzel/fuzzel.ini;

  # Mako notifications — generated from theme.nix.
  # force: set-res.sh rewrites at runtime; must not back up.
  xdg.configFile."mako/config" = {
    force = true;
    text = ''
      # mako — corner popup + fade, gruvbox
      # layer=top renders below fullscreen windows (overlay would cover games).
      font=${theme.font.family} ${toString theme.font.points.mako}
      background-color=${pal.bg}EE
      text-color=${pal.fg}
      border-color=${pal.blue}
      border-size=${toString theme.makoBorder}
      border-radius=0
      default-timeout=4000
      anchor=top-right
      margin=${toString theme.makoMargin}
      padding=${toString theme.makoPadding}
      layer=top

      [urgency=high]
      background-color=${pal.red}E6
    '';
  };

  # Scripts referenced from sway config
  xdg.configFile."sway/scripts/screenshot.sh" = {
    source = ./sway/scripts/screenshot.sh;
    executable = true;
  };
  xdg.configFile."sway/scripts/ws-clean.sh" = {
    source = ./sway/scripts/ws-clean.sh;
    executable = true;
  };
  xdg.configFile."sway/scripts/ws-list.sh" = {
    source = ./sway/scripts/ws-list.sh;
    executable = true;
  };
  xdg.configFile."sway/scripts/keys.sh" = {
    source = ./sway/scripts/keys.sh;
    executable = true;
  };
  xdg.configFile."sway/scripts/notif-history.sh" = {
    source = ./sway/scripts/notif-history.sh;
    executable = true;
  };
  xdg.configFile."sway/scripts/waybar-disk.sh" = {
    source = ./sway/scripts/waybar-disk.sh;
    executable = true;
  };
  xdg.configFile."sway/scripts/wlsunset-toggle.sh" = {
    source = ./sway/scripts/wlsunset-toggle.sh;
    executable = true;
  };
  xdg.configFile."sway/scripts/bluejay-toggle.sh" = {
    source = ./sway/scripts/bluejay-toggle.sh;
    executable = true;
  };
  # pavucontrol-toggle.sh — toggle from the waybar volume icon. GDK_SCALE
  # follows the resolution preset (set-res.sh writes SCALE=… to
  # ~/.config/sway/preset on every switch); fallback = theme value (4K).
  # (bluejay needs no shim: it scales via the global QT_SCALE_FACTOR.)
  # force: set-res.sh rewrites at runtime.
  xdg.configFile."sway/scripts/pavucontrol-toggle.sh" = {
    force = true;
    executable = true;
    text = ''
      #!/usr/bin/env sh
      # Toggle pavucontrol from the waybar volume icon on-click.
      # If it's running, close it; if not, launch it. The sway for_window rule
      # (floating + move position, from machine/theme.nix) anchors it on open.
      #
      # DETECTION: match the WINDOW, not the process. The nixpkgs wrapper
      # renames the ELF (.pavucontrol-wrapped, comm `.pavucontrol-wr`), so a
      # process-name match (this script used to pgrep -x '.pavucontrol-wr')
      # silently breaks whenever that wrapper naming changes — it always
      # launches and never closes. sway's criteria are the stable handle: the
      # same app_id/class rules float and position the window, and set-res.sh
      # closes it by the same criteria. Both kills run because the XWayland
      # window matches on class.
      #
      # X11 (XWayland) backend is REQUIRED for scaling: GTK3's Wayland backend
      # ignores GDK_SCALE (verified — identical window size on native Wayland),
      # the X11 backend honors it.
      if swaymsg -t get_tree | grep -qi pavucontrol; then
        swaymsg '[app_id="(?i)pavucontrol"]' kill >/dev/null 2>&1 || true
        swaymsg '[class="(?i)pavucontrol"]' kill >/dev/null 2>&1 || true
      else
        [ -f "$HOME/.config/sway/preset" ] && . "$HOME/.config/sway/preset"
        GDK_BACKEND=x11 GDK_SCALE="''${SCALE:-${toString theme.display.gtk.xwayland}}" pavucontrol >/dev/null 2>&1 &
      fi
    '';
  };

  # swayosd: 2x-scale OSD. force: set-res.sh rewrites at runtime.
  xdg.configFile."swayosd/style.css" = {
    force = true;
    source = ./swayosd/style.css;
  };

  # Kanshi config
  xdg.configFile."kanshi/config".source = ./kanshi/config;
}
