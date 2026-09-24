{ pkgs, unstable, config, ... }:

let
  theme  = import ../machine/theme.nix;
  identity = import ../machine/identity.nix;
  pal    = theme.palette;
  # pavucontrol 6.x is GTK4/gtkmm (non-libadwaita): its only theming path is
  # GTK_THEME + a gtk-4.0/gtk.css in the theme dir — the gruvbox package ships
  # none, so one is generated from the palette. NOT cruft (removed once, broke
  # pavucontrol).
  gtk4css = import ../machine/gtk4-theme.nix theme;
  resolution = import ../machine/resolution.nix theme;

  # Recolored Bibata cursor theme shared by the sway session and regreet.
  recoloredCursors = import ./cursor/theme.nix { inherit pkgs; colors = theme.palette; };
in
{
  # Runtime resolution presets ($mod+F10/11/12) — self-contained in machine/.
  imports = [ resolution ];

  home.username = identity.username;
  home.stateVersion = "26.05";

  # ---------------------------------------------------------------------------
  # Packages (user scope — GUI apps and things configured via home-manager)
  # ---------------------------------------------------------------------------
  home.packages = with pkgs; [
    ghostty                # terminal
    qalculate-gtk          # calculator (floating window rule exists for it)
    jq                     # used by sway screenshot/res scripts

    # Sway session binaries (fuzzel, waybar, kanshi, swaylock, swayidle, mako)
    # come from programs.sway.extraPackages in modules/desktop.nix, so they sit
    # on the sway session's PATH — not duplicated here.
    nwg-displays           # GUI monitor arranger — SESSION-ONLY, never saved
    swayosd                # volume/brightness OSD popups
    libpulseaudio          # pactl, for low-level audio control
    networkmanagerapplet   # nm-applet: wifi tray menu + secrets agent
    wlsunset               # nightlight (orange), hotkey-only toggle ($mod+o)
    polkit_gnome           # polkit-gnome-authentication-agent-1 (root prompts)
    fastfetch              # system info fetch
    imagemagick            # convert (required by scripts/build_db.py)
    libwebp                # cwebp (required by scripts/build_db.py)
    kdePackages.dolphin    # file manager
    pavucontrol            # per-app volume (XWayland wrapper via launch script)
    # Fuzzel/app-menu launches hit the package .desktop (plain `pavucontrol`),
    # losing the GDK_SCALE/XWayland env → unscaled native window. Same env as
    # pavucontrol-toggle.sh; reads the resolution preset SCALE set by set-res.sh.
    (pkgs.writeShellScriptBin "pavucontrol-scaled" ''
      [ -f "$HOME/.config/sway/preset" ] && . "$HOME/.config/sway/preset"
      exec env GDK_BACKEND=x11 GDK_SCALE="''${SCALE:-${toString theme.display.gtk.pavucontrol}}" pavucontrol
    '')
    # Bluejay (Qt6/QML Kirigami) needs the QQC2 Desktop Style (org.kde.desktop)
    # in its QML import path, or QtQuickControls falls back to the light Basic
    # style (white window). The style paints via QStyle (kvantum) + the KDE
    # color scheme (GruvboxDark), so it matches Dolphin once present.
    (pkgs.bluejay.overrideAttrs (old: {
      buildInputs = (old.buildInputs or []) ++ [ pkgs.kdePackages.qqc2-desktop-style ];
    }))

    # Bluetooth monitoring / debugging
    bluetuith                     # TUI bluetooth manager (connect, send files, monitor)
    bluez-tools                   # btmgmt, btinfo CLI tools for scripted BT control

    # QML shell — game launcher menu (home/quickshell/). Locally patched to
    # read gamepad input from evdev (mod chords + menu navigation) and
    # dispatch it as in-process IPC calls (QS_GAMEPAD_IPC_TARGET /
    # QS_GAMEPAD_HOME_FUNCTION redirect). Patches live in ../patches/ and
    # target nixpkgs' quickshell 0.3.0 — re-base on version drift, both
    # sides fail loudly. Disclosed prototype for
    # quickshell-mirror/quickshell#1189, not upstreamable as-is.
    (quickshell.overrideAttrs (old: {
      patches = (old.patches or [ ]) ++ [ ../patches/quickshell-gamepad-0.3.0.patch ];
      # Was RelWithDebInfo + separateDebugInfo. -g costs ~20-40% compile time
      # per TU and the split debug output was 87MB. NDEBUG was already set by
      # RelWithDebInfo, so only -O2→-O3 + no-debug-info change. Tradeoff:
      # cpptrace/gdb crash traces lose source lines (function names survive).
      cmakeBuildType = "Release";
      separateDebugInfo = false;
    }))
  ];

  xdg.desktopEntries.batteryscope = {
    name = "BatteryScope";
    comment = "Battery health and degradation trends";
    exec = "${pkgs.mise}/bin/mise exec -- BatteryScope";
    terminal = false;
    categories = ["Utility" "Monitor"];
    icon = "battery-full";
  };

  # Same file id as the package entry → overrides it in ~/.local/share/
  # applications, so fuzzel launches the scaled (XWayland) wrapper instead of
  # bare `pavucontrol`. Keep the original Name/Icon/Keywords for searchability.
  xdg.desktopEntries."org.pulseaudio.pavucontrol" = {
    name = "Volume Control";
    genericName = "Volume Control";
    comment = "Adjust the volume level";
    exec = "pavucontrol-scaled";
    icon = "org.pulseaudio.pavucontrol";
    terminal = false;
    categories = [ "AudioVideo" "Audio" "Mixer" "GTK" "Settings" ];
    settings.Keywords = "pavucontrol;PulseAudio;Microphone;Volume;Mixer;Audio;Settings;";
  };

  # Default applications
  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      # images → gwenview
      "image/jpeg"          = "org.kde.gwenview.desktop";
      "image/png"           = "org.kde.gwenview.desktop";
      "image/gif"           = "org.kde.gwenview.desktop";
      "image/webp"          = "org.kde.gwenview.desktop";
      "image/bmp"           = "org.kde.gwenview.desktop";
      "image/tiff"          = "org.kde.gwenview.desktop";
      "image/heic"          = "org.kde.gwenview.desktop";
      "image/heif"          = "org.kde.gwenview.desktop";
      "image/avif"          = "org.kde.gwenview.desktop";
      "image/svg+xml"       = "org.kde.gwenview.desktop";
      "image/x-xbitmap"     = "org.kde.gwenview.desktop";
      "image/x-xpixmap"     = "org.kde.gwenview.desktop";
      "image/x-icon"        = "org.kde.gwenview.desktop";
      "image/vnd.microsoft.icon" = "org.kde.gwenview.desktop";
      "image/x-portable-pixmap"  = "org.kde.gwenview.desktop";
      "image/x-tga"         = "org.kde.gwenview.desktop";
      "image/jxl"           = "org.kde.gwenview.desktop";
      "image/x-canon-cr2"   = "org.kde.gwenview.desktop";
      "image/x-canon-cr3"   = "org.kde.gwenview.desktop";
      "image/x-nikon-nef"   = "org.kde.gwenview.desktop";
      "image/x-sony-arw"    = "org.kde.gwenview.desktop";

      # video → vlc
      "video/mp4"           = "vlc.desktop";
      "video/x-matroska"    = "vlc.desktop";
      "video/webm"          = "vlc.desktop";
      "video/avi"           = "vlc.desktop";
      "video/x-msvideo"     = "vlc.desktop";
      "video/quicktime"     = "vlc.desktop";
      "video/x-flv"         = "vlc.desktop";
      "video/mpeg"          = "vlc.desktop";
      "video/ogg"           = "vlc.desktop";
      "video/x-theora+ogg"  = "vlc.desktop";
      "video/3gpp"          = "vlc.desktop";
      "video/3gpp2"         = "vlc.desktop";
      "video/dvd"           = "vlc.desktop";
      "video/x-ms-wmv"      = "vlc.desktop";
      "application/x-matroska" = "vlc.desktop";
      "application/mp4"     = "vlc.desktop";
      "application/x-mpegURL"     = "vlc.desktop";
      "application/vnd.apple.mpegurl" = "vlc.desktop";
      "audio/x-mpegurl"     = "vlc.desktop";
      "audio/mpegurl"       = "vlc.desktop";
    };
  };

  # Flatpak (managed via nix-flatpak module)
  services.flatpak.packages = [
    "net.retrodeck.retrodeck"
  ];

  # EasyEffects: system-wide audio effects (EQ, compression, limiter).
  # Auto-starts with the pipewire session; dconf backing store is already
  # enabled system-wide (modules/desktop.nix) so settings persist.
  services.easyeffects.enable = true;

  # Cursor: bigger + a real theme (default is a tiny X cursor)
  home.sessionVariables = {
    XCURSOR_SIZE = toString theme.display.cursor.env;
    XCURSOR_THEME = theme.cursorTheme;
  };

  # Recolored Bibata from the single built package shared with regreet, so
  # sway session and greeter show the same cursor.
  home.file.".icons/Bibata-Modern-Classic".source =
    "${recoloredCursors}/share/icons/Bibata-Modern-Classic";

  # Desktop wallpaper (gruvbox astronaut, 4K) — installed to a stable path so
  # sway's output bg (absolute path) works.
  home.file.".local/share/backgrounds/gruvbox-astronaut-4k.png".source =
    ../images/gruvbox_astronaut-4k.png;

  # X11 apps (Electron on XWayland) resolve cursor via libXcursor —
  # ~/.icons/default must exist and inherit.
  home.file.".icons/default/index.theme".text = ''
    [Icon Theme]
    Inherits=${theme.cursorTheme}
  '';

  # Ghostty terminal — config written directly (no HM module: that adds a
  # systemd single-instance daemon + shell integration we don't want).
  # Values from theme.nix. force: set-res.sh rewrites font-size at runtime.
  home.file.".config/ghostty/config" = {
    force = true;
    text = ''
      theme = "Gruvbox Dark"
      font-family = ${theme.font.family}
      font-size = ${toString theme.font.points.ghostty}
      copy-on-select = clipboard
    '';
  };

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

  # fastfetch: no config override, uses defaults (auto-detects NixOS logo).

  # bash: zsh is the login shell; this only keeps interactive bash working
  # (HM writes ~/.bashrc so session variables are sourced there too).
  programs.bash.enable = true;

  # ---------------------------------------------------------------------------
  # Shell: zsh — fzf-tab fuzzy completion on <Tab>, fzf history on <Ctrl+R>
  # ---------------------------------------------------------------------------
  programs.zsh = {
    enable = true;
    shellAliases = {
      sa2-mods = "$HOME/nixos-config/SA2 Modding/launch-manager.sh";
      sa2-setup = "$HOME/nixos-config/SA2 Modding/setup-sa2b.sh";
    };
    enableCompletion = true;
    history = {
      path = "$HOME/.config/zsh/.zsh_history";
      size = 50000;
      save = 50000;
      ignoreDups = true;
      ignoreAllDups = true;
      ignoreSpace = true;
      findNoDups = true;
      share = true;
    };
    plugins = [
      {
        name = "fzf-tab";
        src = pkgs.zsh-fzf-tab;
        file = "share/fzf-tab/fzf-tab.zsh";
      }
    ];
    initContent = ''
  # fzf-tab: <Tab> opens a fuzzy finder for the current directory
      zstyle ':completion:*' menu no
      zstyle ':fzf-tab:*' switch-group '<' '>'

      # Preview the directory when tab-completing cd / paths
      zstyle ':fzf-tab:complete:cd:*' fzf-preview \
        'ls -1 --color=always $realpath 2>/dev/null || echo $realpath'
      zstyle ':fzf-tab:complete:cd:*' fzf-flags '--height=40%' '--layout=reverse' '--border'

      # Kill completion: preview the command behind the PID being completed
      zstyle ':fzf-tab:complete:kill:argument-*' fzf-preview \
        'ps --pid=$word -o comm --no-headers 2>/dev/null || true'

      # ---- lazy Ctrl+R: fuzzy history search ----
      if [[ -o zle ]]; then
        _fzf_history() {
          local sel
          sel=$(fc -ln 1 | fzf --height=40% --layout=reverse --border --query="$BUFFER")
          if [[ -n "$sel" ]]; then
            BUFFER="$sel"
            CURSOR=$#BUFFER
          fi
          zle reset-prompt
        }
        zle -N _fzf_history
        bindkey '^R' _fzf_history
      fi

      # ---- bare prompt: ~/path ❯ (hot-pink), red ❯ on error ----
      PROMPT='%B%F{${pal.accent}}%~%f %(!.%F{#fb4934}#.%(?.%F{${pal.accent}}.%F{#fb4934})❯)%f%b '
    '';
  };

  # fzf: installs the binary (fzf-tab needs it); zsh integration disabled —
  # Ctrl+R is a lazy widget that spawns fzf only when pressed.
  programs.fzf = {
    enable = true;
    enableZshIntegration = false;
  };

  programs.mise = {
    enable = true;
    package = unstable.mise;
  };

  xdg.configFile."mise/config.toml".text = ''
    [tools]
    opencode = "latest"
    "github:tontinton/maki" = "latest"
    "github:yt-dlp/yt-dlp" = { version = "latest", github_attestations = false }
    deno = "latest"
    golang = "latest"
    "github:ptcodes/BatteryScope" = "latest"
  '';

  programs.gh.enable = true;

  programs.git = {
    enable = true;
    settings = {
      user.name = "ShadyHippo";
      user.email = "tim.vandyke123@gmail.com";
      push.autoSetupRemote = true;
    };
};

  # VSCode config lives in machine/vscode.nix (trimmable user favorite).

  # ---------------------------------------------------------------------------
  # Sway — home/sway/config holds the static config (keybindings, rules,
  # ---------------------------------------------------------------------------
  # Sway — home/sway/config holds the static config (keybindings, rules,
  # autostart). The 8 dynamic values below are appended via extraConfig from
  # machine/theme.nix (sway applies last-wins, so appending overrides cleanly).
  # ---------------------------------------------------------------------------
  wayland.windowManager.sway = {
    enable = true;
    config = null;
    # The config references the wallpaper at ~/.local/share/backgrounds/...,
    # which only exists AFTER activation — skip the sandboxed build-time check.
    checkConfig = false;
    extraConfig = let
      pavu = theme.popups.pavucontrol;
      blu  = theme.popups.bluejay;
    in
      (builtins.readFile ./sway/config) + ''
      # ── Dynamic values from machine/theme.nix (appended: last-wins) ──
      font ${theme.font.family} ${toString theme.font.points.sway}
      seat * xcursor_theme ${theme.cursorTheme} ${toString theme.display.cursor.seat}
      output eDP-1 bg ${theme.wallpaper} fill
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
      # DETECTION (verified): the real pavucontrol process has:
      #   comm    = `.pavucontrol-wr`   (a leading dot + `-wr` suffix, NOT `pavucontrol`)
      #   exe     = .../.pavucontrol-wrapped
      #   cmdline = `pavucontrol`  (bare name — a `-f '/bin/pavucontrol'` match is NOT it)
      # So match on the process-name form `.pavucontrol-wr`, which is stable.
      # `pavucontrol` (no -f) would self-match other processes, and `-f pavucontrol`
      # matches this script's own argv too. `.pavucontrol-wr` is unambiguous.
      #
      # X11 (XWayland) backend is REQUIRED for scaling: GTK3's Wayland backend
      # ignores GDK_SCALE (verified — identical window size on native Wayland),
      # the X11 backend honors it.
      if pgrep -x '.pavucontrol-wr' >/dev/null 2>&1; then
        pkill -x '.pavucontrol-wr'
      else
        [ -f "$HOME/.config/sway/preset" ] && . "$HOME/.config/sway/preset"
        GDK_BACKEND=x11 GDK_SCALE="''${SCALE:-${toString theme.display.gtk.pavucontrol}}" pavucontrol >/dev/null 2>&1 &
      fi
    '';
  };

  # swayosd: 2x-scale OSD. force: set-res.sh rewrites at runtime.
  xdg.configFile."swayosd/style.css" = {
    force = true;
    source = ./swayosd/style.css;
  };

  # Waybar config — static content from the template, with bar sizes
  # substituted from theme.nix. (The @TOKEN@ approach here is deliberate:
  # generating the entire JSON in Nix would lose the inline comments.)
  # force: set-res.sh rewrites at runtime; must not back up.
  xdg.configFile."waybar/config.jsonc" = {
    force = true;
    text = builtins.replaceStrings
      [ "@BAR_ICON_SIZE@" "@BAR_SPACING@" ]
      [ (toString theme.bar.iconSize) (toString theme.bar.spacing) ]
      (builtins.readFile ./waybar/config.jsonc);
  };
  xdg.configFile."waybar/style.css" = {
    force = true;
    text = ''
      /* waybar — gruvbox, generated from machine/theme.nix */
      * {
          border: none;
          border-radius: 0;
          font-family: "${theme.font.family}", sans-serif;
          font-size: ${toString theme.font.points.waybar}px;
          min-height: 0;
      }

      window#waybar {
          background: ${pal.bg};
          color: ${pal.fg};
      }

      #workspaces button {
          padding: 0 6px;
          min-width: ${toString theme.bar.fontMinWidth}px;
          background: transparent;
          color: ${pal.fgDim};
      }

      #workspaces button.focused {
          background: ${pal.blue};
          color: ${pal.bg};
      }

      #workspaces button.urgent {
          background: ${pal.red};
          color: ${pal.fg};
      }

      #window {
          font-style: italic;
      }

      #clock,
      #battery,
      #bluetooth,
      #memory,
      #custom-disk,
      #temperature,
      #pulseaudio,
      #tray {
          padding: 0 8px;
          background: transparent;
      }

      #memory.warning,
      #custom-disk.warning,
      #temperature.warning {
          color: ${pal.yellow};
      }

      #memory.critical,
      #custom-disk.critical {
          color: #fb4934;
      }

      #battery.warning {
          color: ${pal.yellow};
      }

      #battery.critical:not(.charging) {
          color: #fb4934;
          animation: blink 1s linear infinite alternate;
      }

      #temperature.critical {
          color: #fb4934;
      }

      #bluetooth.connected {
          color: ${pal.accent};
      }

      #bluetooth.off,
      #bluetooth.disabled {
          color: ${pal.gray};
      }

      @keyframes blink {
          to {
              background: ${pal.red};
              color: ${pal.bg};
          }
      }
    '';
  };

  # Kanshi config
  xdg.configFile."kanshi/config".source = ./kanshi/config;

  # QuickShell game-launcher menu (home/quickshell/shell.qml → the 'default'
  # config at ~/.config/quickshell/shell.qml, run by `qs`). Same @TOKEN@
  # approach as waybar: palette/font from theme.nix, icons from images/ (SVG,
  # crisp at any preset), absolute binary paths so nothing depends on PATH.
  # Autostart + $mod+g toggle live in home/sway/config. HM symlinks this file
  # into the store, so qs hot-reload can't see across rebuilds — restart `qs`
  # after switching to pick changes up (`qs kill`, then relaunch).
  xdg.configFile."quickshell/shell.qml".text = builtins.replaceStrings
    [ "@PAL_BG@" "@PAL_BGALT@" "@PAL_BGDIM@" "@PAL_FG@" "@PAL_FGDIM@"
      "@PAL_ACCENT@" "@FONT@"
      "@ICON_RETRODECK@" "@ICON_MOONLIGHT@" "@ICON_STEAM@"
      "@BIN_FLATPAK@" "@BIN_MOONLIGHT@" "@BIN_STEAM@" "@BIN_SH@" "@SET_RES@"
      "@BIN_SWAYMSG@" "@WS_CLEAN@" "@WS_LIST@" ]
    [ pal.bg pal.bgAlt pal.bgDim pal.fg pal.fgDim
      pal.accent theme.font.family
      "${../images/retrodeck.svg}" "${../images/moonlight.svg}" "${../images/steam.svg}"
      "${pkgs.flatpak}/bin/flatpak" "${pkgs.moonlight-qt}/bin/moonlight"
      "${pkgs.steam}/bin/steam" "${pkgs.bash}/bin/bash"
      "${config.home.homeDirectory}/.config/sway/scripts/set-res.sh"
      "${pkgs.sway}/bin/swaymsg"
      "${config.home.homeDirectory}/.config/sway/scripts/ws-clean.sh"
      "${config.home.homeDirectory}/.config/sway/scripts/ws-list.sh" ]
    (builtins.readFile ./quickshell/shell.qml);

  # Accent + legacy prefer-dark key that the `gtk` module does NOT write
  # (module owns color-scheme/font/cursor/theme via dconf below).
  dconf.settings = {
    "org/gnome/desktop/interface" = {
      accent-color = "amber";
      gtk-application-prefer-dark-theme = true;
    };
  };

  # GTK theming via the home-manager `gtk` module — the documented way.
  # It generates gtk-3.0/settings.ini AND mirrors the same keys into dconf
  # (org.gnome.desktop.interface), so apps launched with a clean env (systemd
  # user services, e.g. easyeffects) get the theme too; the theme package is
  # also installed to the user profile (~/.nix-profile/share on XDG_DATA_DIRS).
  # NOTE: set-res.sh still force-rewrites settings.ini at runtime (preset
  # switches) — that behaviour is unchanged.
  gtk = {
    enable = true;
    colorScheme = "dark";   # → gtk-application-prefer-dark-theme + prefer-dark
    font = {
      name = theme.font.family;
      size = 18;
    };
    theme = {
      name = theme.gtkTheme;
      package = pkgs.gruvbox-dark-gtk;
    };
    iconTheme = {
      name = "Adwaita";
      package = pkgs.adwaita-icon-theme;
    };
    cursorTheme = {
      name = theme.cursorTheme;
      package = recoloredCursors;
      size = theme.display.cursor.seat;
    };
    # GTK4: stateVersion 26.05 keeps gtk4.theme null (libadwaita defaults).
  };

  # GTK4 gruvbox css for non-libadwaita GTK4 apps (pavucontrol 6.x): consumed
  # via GTK_THEME=gruvbox-dark → ~/.local/share/themes/gruvbox-dark/gtk-4.0/.
  # Don't remove — pavucontrol does not go through gtk3 settings/dconf at all.
  xdg.dataFile."themes/gruvbox-dark/gtk-4.0/gtk.css".text = gtk4css;

  # Belt-and-suspenders: the gtk module resolves the theme via the user
  # profile (XDG_DATA_DIRS). A ~/.themes copy additionally covers contexts
  # whose env may lack that path (some systemd user services) — GTK3 always
  # checks ~/.themes first, keyed only on $HOME.
  home.file.".themes/gruvbox-dark".source =
    "${pkgs.gruvbox-dark-gtk}/share/themes/gruvbox-dark";

  # KDE palette+font (Dolphin) + KColorScheme source for Kirigami apps
  # (bluejay). The Qt platform theme (kde) resolves the .colors SCHEME FILE
  # via [General] ColorScheme for QWidgets palettes — but raw KColorScheme,
  # which drives Kirigami/QML theming, reads the [Colors:*] groups STRAIGHT
  # from kdeglobals and falls back to hardcoded Breeze Light when they're
  # absent (that was the white bluejay). So inline the scheme groups here;
  # the .colors file keeps the name-resolution side. Single source of truth.
  home.file.".config/kdeglobals".text = ''
    [General]
    font=${theme.font.family},18,-1,5,50,0,0,0,0,0
    ColorScheme=GruvboxDark
  '' + builtins.readFile ./color-schemes/GruvboxDark.colors;

  home.file.".local/share/color-schemes/GruvboxDark.colors".source =
    ./color-schemes/GruvboxDark.colors;

  # Kvantum: select the gruvbox theme for all non-KDE Qt apps.
  home.file.".config/Kvantum/kvantum.kvconfig".text = ''
    [General]
    theme=${theme.qtTheme}
  '';

  # Kvantum theme: symlink the store .svg + patched .kvconfig into
  # ~/.config/Kvantum/ (Kvantum ignores XDG_DATA_DIRS, nixpkgs#355277).
  home.file.".config/Kvantum/Gruvbox-Dark-Brown/Gruvbox-Dark-Brown.svg".source =
    "${pkgs.gruvbox-kvantum}/share/Kvantum/Gruvbox-Dark-Brown/Gruvbox-Dark-Brown.svg";
  home.file.".config/Kvantum/Gruvbox-Dark-Brown/Gruvbox-Dark-Brown.kvconfig".source =
    ./kvantum/Gruvbox-Dark-Brown.kvconfig;
}
