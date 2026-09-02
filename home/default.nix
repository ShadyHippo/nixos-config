{ pkgs, unstable, ... }:

let
  theme  = import ../modules/theming.nix;   # colors/themes (edit to re-theme)
  sizing = import ../modules/sizing.nix;    # fonts/scales/layout (edit for other screens)
  pal    = theme.palette;                   # shorthand for the gtk-4.0 css below
  # Recolored Bibata cursor theme shared by the sway session and regreet.
  recoloredCursors = import ./cursor/theme.nix { inherit pkgs; colors = theme.palette; };
in
{
  home.username = "hippo";
  home.stateVersion = "26.05";

  # ---------------------------------------------------------------------------
  # Packages (user scope)
  # ---------------------------------------------------------------------------
  home.packages = with pkgs; [
    ghostty                # terminal
    vscode                 # VS Code — from the stable nixpkgs pin (no overlay is actually wired)
    neovim                 # Neovim — from the stable nixpkgs pin (no nightly overlay)
    qalculate-gtk          # calculator (floating window rule exists for it)
    jq                     # used by sway screenshot/res scripts

    # Sway session
    fuzzel                 # app launcher ($mod+d)
    waybar                 # status bar
    kanshi                 # monitor hotplug profiles
    swaylock               # screen lock
    swayidle               # idle lock/dpms
    mako                   # notifications
    nwg-displays           # GUI monitor arranger — SESSION-ONLY, never saved (kanshi is durable)

    kdePackages.dolphin
    dolphin-emu            # GameCube/Wii emulator
    # snes9x-gtk 1.63 in the 26.05 pin fails to build (jma target missing
    # 'target_compile_definitions(jma PRIVATE ${DEFINES})' -> unzip.h not
    # found). Patched with upstream PR #1033 (merged 2026-03-21).
    (snes9x-gtk.overrideAttrs (old: {
      postPatch = (old.postPatch or "") + ''
        substituteInPlace gtk/CMakeLists.txt \
          --replace-fail 'target_compile_options(jma PUBLIC ''${ARGS})' \
                        'target_compile_options(jma PUBLIC ''${ARGS})
target_compile_definitions(jma PRIVATE ''${DEFINES})'
      '';
    }))                 # SNES emulator (GTK UI)

    swayosd                 # volume/brightness OSD popups (server autostarted in sway)
    libpulseaudio            # pactl, for low-level audio control
    networkmanagerapplet     # nm-applet: wifi tray menu + secrets agent (autostarted in sway)
    wlsunset                 # nightlight, hotkey-only toggle ($mod+Shift+u)
    polkit_gnome             # polkit-gnome-authentication-agent-1 (root prompts) - autostarted in sway

    # System info fetch (modern neofetch drop-in — neofetch is unmaintained)
    fastfetch

    # image tooling — convert (imagemagick) + cwebp (libwebp): required by
    # scripts/build_db.py for thumbnail resize (--thumb 128) + WebP encoding
    imagemagick
    libwebp
  ];

  # Cursor: bigger + a real theme (default is a tiny X cursor)
  home.sessionVariables = {
    XCURSOR_SIZE = toString sizing.display.cursor.env;
    XCURSOR_THEME = theme.cursorTheme;
  };

  # Recolored Bibata from the single built package shared with regreet, so the
  # sway session and the greeter show the SAME hot-pink cursor. home.file
  # shadows the store copy; colors come from modules/theming.nix (accent+green).
  home.file.".icons/Bibata-Modern-Classic".source =
    "${recoloredCursors}/share/icons/Bibata-Modern-Classic";

  # Desktop wallpaper (gruvbox astronaut, 4K). Installed to a stable path so the
  # sway config `output bg` (which needs an absolute path) just works.
  home.file.".local/share/backgrounds/gruvbox-astronaut-4k.png".source =
    ../images/gruvbox_astronaut-4k.png;

  # X11 apps (Discord/Signal = Electron on XWayland) don't get the cursor via
  # sway's seat, they resolve it via libXcursor: ~/.icons/default must exist
  # and inherit, otherwise they fall back to the stock X cursor.
  home.file.".icons/default/index.theme".text = ''
    [Icon Theme]
    Inherits=Bibata-Modern-Classic
  '';

  # force: set-res.sh rewrites font-size at runtime (F10/F11/F12) — the file is
  # often non-base at switch time, so HM must reset it WITHOUT backing up (a
  # .bak would collide with the stale one from the last dirty switch).
  home.file.".config/ghostty/config" = {
    force = true;
    text = builtins.replaceStrings
      [ "font-family = Cousine Nerd Font" "font-size = 18" ]
      [ ("font-family = " + sizing.font.family) ("font-size = " + toString sizing.font.points.ghostty) ]
      (builtins.readFile ./ghostty/config);
  };

  # VS Code icon: the package ships hicolor/1024x1024/apps/vscode.png but the
  # launcher shows a blank box; pin it into the user icon theme so it resolves.
  home.file.".local/share/icons/hicolor/128x128/apps/vscode.png".source =
    "${pkgs.vscode}/share/icons/hicolor/1024x1024/apps/vscode.png";

  # fcitx5: preseed IMs (keyboard-us + Pinyin) + trigger keys. Without this the
  # profile only has keyboard-us, so the tray shows "input" and clicking it does
  # nothing. Restart fcitx5 after switching (relogin or `fcitx5 -d --replace`).
  xdg.configFile."fcitx5/profile".text = ''
    [Profile]
    EnabledIMList=pinyin:False,keyboard-us:True

    [Groups/0]
    # Group Name
    Name=Default
    # Layout
    Default Layout=us
    # Default Input Method
    DefaultIM=keyboard-us

    [Groups/0/Items/0]
    # Name
    Name=keyboard-us
    # Layout
    Layout=

    [Groups/0/Items/1]
    # Name
    Name=pinyin
    # Layout
    Layout=

    [GroupOrder]
    0=Default
  '';

  # KeyList is comma-separated (fcitx5 source, globalconfig.cpp). Toggle =
  # Ctrl+Super+a (user's choice; Ctrl+Space dropped - VS Code uses it for
  # IntelliSense, and it was unreliable in some apps anyway).
  # ShareInputState=All makes the IM state GLOBAL (not per-app; default No).
  # Enum verified in fcitx5 globalconfig.cpp BehaviorConfig.
  xdg.configFile."fcitx5/config".text = ''
    [Hotkey]
    TriggerKeys=Control+Super+a

    [Behavior]
    ShareInputState=All
  '';

  # fcitx5 UI is sized off the Classic UI font (default "Sans 10" per
  # classicui.h). On 4K@scale 1 that renders ~10px. Doubled to 20 for the
  # candidate window, tray menu, and tray label (flat INI, no [General]
  # section). Restart fcitx5 after switching (relogin or `fcitx5 -d --replace`).
  xdg.configFile."fcitx5/conf/classicui.conf".text = ''
    Font=Sans 24
    MenuFont=Sans 24
    TrayFont=Sans Bold 24
  '';

  xdg.configFile."fuzzel/fuzzel.ini".source = ./fuzzel/fuzzel.ini;
  # force: set-res.sh rewrites this at runtime (F10/F11/F12) — reset to base
  # without backing up (see ghostty/config comment for the .bak collision).
  xdg.configFile."mako/config" = {
    force = true;
    text = builtins.replaceStrings
      [ "font=Cousine Nerd Font 16" "margin=24" "padding=10" "border-size=2"
        "#282828EE" "#ebdbb2" "#83a598" "#cc241dE6"
      ]
      [ ("font=${sizing.font.family} " + toString sizing.font.points.mako)
        ("margin=" + toString sizing.makoMargin)
        ("padding=" + toString sizing.makoPadding)
        ("border-size=" + toString sizing.makoBorder)
        (theme.palette.bg + "EE") theme.palette.fg theme.palette.blue (theme.palette.red + "E6")
      ]
      (builtins.readFile ./mako/config);
  };

  # fastfetch (neofetch drop-in): no config override — uses pure defaults,
  # which auto-detects + prints the NixOS logo. My earlier custom config
  # disabled the logo with "type":"none". Remove it to get the logo back.

  # pinyin ready at login (Ctrl+Super+A)
  programs.bash.enable = true;

  # ---------------------------------------------------------------------------
  # Shell: zsh — fzf-tab fuzzy completion on <Tab>, fzf history on <Ctrl+R>, bare prompt
  # ---------------------------------------------------------------------------
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    plugins = [
      {
        name = "fzf-tab";
        src = pkgs.zsh-fzf-tab;
        file = "share/fzf-tab/fzf-tab.zsh";
      }
    ];
    initContent = ''
      # ---- fzf-tab: <Tab> opens a fuzzy finder for the current directory ----
      zstyle ':completion:*' menu no
      zstyle ':fzf-tab:*' switch-group '<' '>'

      # Preview the directory when tab-completing cd / paths
      zstyle ':fzf-tab:complete:cd:*' fzf-preview \
        'ls -1 --color=always $realpath 2>/dev/null || echo $realpath'
      zstyle ':fzf-tab:complete:cd:*' fzf-flags '--height=40% --layout=reverse --border'

      # Kill completion: preview the command behind the PID being completed
      zstyle ':fzf-tab:complete:kill:argument-*' fzf-preview \
        'ps --pid=$word -o comm --no-headers 2>/dev/null || true'

      # ---- lazy Ctrl+R: fuzzy history search (fzf only runs when pressed) ----
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

      # ---- bare prompt: ~/path ❯ (hot-pink), red ❯ on error, red # as root ----
      zmodload zsh/datetime
      autoload -Uz add-zsh-hook
      _sp_dur=""
      _sp_start=""
      _sp_preexec() { _sp_start=$EPOCHREALTIME; }
      _sp_precmd() {
        if [[ -n "$_sp_start" ]]; then
          local s=$(( EPOCHREALTIME - _sp_start ))
          printf -v _sp_dur '%.2fs' $s
          RPROMPT="%F{#928374}took $_sp_dur%f"
        else
          RPROMPT=""
        fi
      }
      add-zsh-hook preexec _sp_preexec
      add-zsh-hook precmd _sp_precmd
      # %~  -> ~ at home, ~/subdir under home, full absolute path elsewhere
      # %(!). = root? (then red #) : (?(. = last cmd ok? pink ❯ : red ❯)
      PROMPT='%B%F{#ff2b6d}%~%f %(!.%F{#fb4934}#.%(?.%F{#ff2b6d}.%F{#fb4934})❯)%f%b '
    '';
  };

  # fzf: installs the binary (fzf-tab needs it); zsh integration disabled —
  # Ctrl+R is a lazy widget in initContent that spawns fzf only when pressed.
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

  programs.vscode = {
    enable = true;
    profiles.default.extensions = with pkgs.vscode-extensions; [
      golang.go
      jdinhlife.gruvbox
      jnoortheen.nix-ide
      mechatroner.rainbow-csv
      oderwat.indent-rainbow
      vscodevim.vim
      llvm-vs-code-extensions.vscode-clangd
      dbaeumer.vscode-eslint
      esbenp.prettier-vscode
      mkhl.direnv
    ];
    profiles.default.userSettings = {
      "workbench.sideBar.location" = "right";
      "window.zoomLevel" = 2.5;
      "files.autoSave" = "afterDelay";      # auto-save (1s after typing stops)
      "editor.formatOnSave" = true;          # format file on save
      "workbench.colorTheme" = "Gruvbox Dark Hard";
      "vim.useSystemClipboard" = true;
      "vim.hlsearch" = true;
      "vim.visualstar" = true;
      "vim.handleKeys" = {
        "<C-p>" = false; # VSCodeVim intercepts Ctrl+P (regression v1.26+); let VS Code's Quick Open win
      };
      "editor.lineNumbers" = "relative";
      "search.showLineNumbers" = true;
      "explorer.confirmDragAndDrop" = false;
      "explorer.confirmDelete" = false;
      "workbench.colorCustomizations" = {
        "editorBracketHighlight.foreground1" = "#003ad8";
        "editorBracketHighlight.foreground2" = "#c58700";
        "editorBracketHighlight.foreground3" = "#ea00ff";
        "editorBracketHighlight.foreground4" = "#0bbe89";
        "editorBracketHighlight.foreground5" = "#fffb00";
        "editorBracketHighlight.foreground6" = "#21c700";
        "editorBracketHighlight.unexpectedBracket.foreground" = "#ff0000";
      };
    };
    profiles.default.keybindings = [
      {
        key = "ctrl+shift+s";
        command = "workbench.action.files.saveAll";   # Save All (overrides Save As default)
      }
      {
        key = "alt+shift+f";
        command = "editor.action.formatDocument";     # format the whole file
        when = "editorTextFocus && !editorReadonly";
      }
    ];
  };

  # ---------------------------------------------------------------------------
  # Sway — plain config file, not Nix attrsets
  # ---------------------------------------------------------------------------
  wayland.windowManager.sway = {
    enable = true;
    # config = null: full config lives in ./sway/config via extraConfig below.
    # Setting null prevents home-manager from generating its own default
    # config, which would spin up a second (i3status) bar alongside waybar.
    config = null;
    # The config references the wallpaper at ~/.local/share/backgrounds/...,
    # which only exists AFTER activation — sway's build-time config check can't
    # see it in the sandbox, so it fails. This is the documented course: skip
    # the sandboxed check (sway still validates + applies the config at login).
    checkConfig = false;
    extraConfig = let
      pavu = sizing.popups.pavucontrol;
      blu  = sizing.popups.blueman;
      fnt  = sizing.font.points;
      pal  = theme.palette;
    in builtins.replaceStrings
      [ # -- font / cursor / wallpaper / titlebar (sizing.nix + theming.nix) --
        "font Cousine Nerd Font 22"
        "seat * xcursor_theme Bibata-Modern-Classic 64"
        "output eDP-1 bg /home/hippo/.local/share/backgrounds/gruvbox-astronaut-4k.png fill"
        "titlebar_padding 4"
        # -- floating popups (sizing.nix -> popups) --
        "move position 2700 1700"
        "move position 2800 80"
        "resize set 1060 500"
        # -- colors (theming.nix -> palette) --
        "#83a598"
        "#282828"
        "#ebdbb2"
        "#665c54"
        "#3c3836"
        "#bdae93"
        "#cc241d"
      ]
      [ "font ${sizing.font.family} ${toString fnt.sway}"
        "seat * xcursor_theme ${theme.cursorTheme} ${toString sizing.display.cursor.seat}"
        "output eDP-1 bg ${theme.wallpaper} fill"
        "titlebar_padding ${toString sizing.titlebarPadding}"
        "move position ${toString pavu.x} ${toString pavu.y}"
        "move position ${toString blu.x} ${toString blu.y}"
        "resize set ${toString blu.w} ${toString blu.h}"
        pal.blue pal.bg pal.fg pal.bgDim pal.bgAlt pal.fgDim pal.red
      ]
      (builtins.readFile ./sway/config) + ''

      # Auto-float dialogs and popups (Dolphin file transfers, file pickers, etc.)
      for_window [window_role="pop-up"] floating enable
      for_window [window_role="dialog"] floating enable
    '';
  };

  # set-res.sh rewrites the installed sway config at runtime (F10/F11/F12), so
  # hm's per-file backup collides with the stale .bak on every switch made at a
  # non-4K preset. force = HM always resets to base, never backs up (merges
  # with the sway module's own definition of this file).
  xdg.configFile."sway/config".force = true;

  # Scripts referenced from sway config
  xdg.configFile."sway/scripts/screenshot.sh" = {
    source = ./sway/scripts/screenshot.sh;
    executable = true;
  };
  # set-res.sh (F10/F11/F12 resolution presets): every number baked in from
  # modules/sizing.nix (presets). The sed patterns live in the script; only the
  # per-preset VALUES are injected here (one token set per preset). The script
  # edits the INSTALLED configs, so its "old" patterns match any number left by
  # the previous preset — no stale-state problem.
  xdg.configFile."sway/scripts/set-res.sh" = let
    pres = sizing.presets;
    fam  = sizing.font.family;
    curs = theme.cursorTheme;
    mkSway = p: builtins.concatStringsSep "\n" (
      # Mode lives IN the config, not a post-reload command: on reload sway
      # re-queues the output to the EDID preferred mode when the config has no
      # mode line, and that deferred commit clobbers any mode set right after
      # the reload (verified). So: delete any eDP-1 mode line, and (sub-4K
      # presets) append our --custom one — one reload applies values + mode
      # atomically. The 4k preset just deletes it (reload → preferred = 4K).
      [ ( "/^output eDP-1 mode/d"
          + (if p.mode == "native" then "" else "\n$a output eDP-1 ${p.mode}") )
        "s|^font .*\\b[0-9]\\+$|font ${fam} ${toString p.fonts.sway}|"
        "s|^seat \\* xcursor_theme .*\\b[0-9]\\+$|seat * xcursor_theme ${curs} ${toString p.cursorSeat}|"
        "s|pointer_accel .*|pointer_accel ${p.accel}|"
        "s|^titlebar_padding .*|titlebar_padding ${toString p.titlebar}|"
        "s|\\(for_window \\[[a-z_]*=\"(?i)pavucontrol\"\\]\\) move position [0-9 ]*|\\1 move position ${toString p.pavu.x} ${toString p.pavu.y}|g"
        "s|\\(for_window \\[[a-z_]*=\"(?i)blueman-manager\"\\]\\) resize set [0-9 x]*|\\1 resize set ${toString p.blueman.w} ${toString p.blueman.h}|g"
        "s|\\(for_window \\[[a-z_]*=\"(?i)blueman-manager\"\\]\\) move position [0-9 ]*|\\1 move position ${toString p.blueman.x} ${toString p.blueman.y}|g"
      ] );
    mkWaybar = p: builtins.concatStringsSep "\n" [
      "s|font-size: [0-9]*px;|font-size: ${toString p.fonts.waybar}px;|"
      "s|min-width: [0-9]*px;|min-width: ${toString p.bar.fontMinWidth}px;|"
      "s|\"height\": [0-9]*|\"height\": ${toString p.bar.height}|"
      "s|\"icon-size\": [0-9]*|\"icon-size\": ${toString p.bar.iconSize}|"
      "s|\"spacing\": [0-9]*|\"spacing\": ${toString p.bar.spacing}|"
    ];
    mkMako = p: builtins.concatStringsSep "\n" [
      "s|^font=.*|font=${fam} ${toString p.fonts.mako}|"
      "s|^margin=[0-9]*|margin=${toString p.mako.margin}|"
      "s|^padding=[0-9]*|padding=${toString p.mako.padding}|"
      "s|^border-size=[0-9]*|border-size=${toString p.mako.border}|"
    ];
    mkGhost = p: "s|^font-size = [0-9.]*|font-size = ${toString p.fonts.ghostty}|";
    mkOsd = p: builtins.concatStringsSep "\n" [
      "s|min-width: [0-9]*px;|min-width: ${toString p.osd.minWidth}px;|"
      "s|margin: [0-9]*px;|margin: ${toString p.osd.margin}px;|"
      "s|font-size: [0-9]*px;|font-size: ${toString p.fonts.osd}px;|"
      "s|-gtk-icon-size: [0-9]*px;|-gtk-icon-size: ${toString p.osd.icon}px;|"
      "s|min-height: [0-9]*px;|min-height: ${toString p.osd.bar}px;|"
      "s|margin-left: [0-9]*px;|margin-left: ${toString p.osd.seg}px;|"
    ];
    mkGtkIni = p: "s|gtk-cursor-theme-size=.*|gtk-cursor-theme-size=${toString p.cursorSeat}|";
    # sed patterns go inside bash double-quoted assignments, so quotes AND dollar
    # signs must be escaped first ($a → the sed append command would otherwise
    # be expanded by bash as the empty variable $a):
    esc = s: builtins.replaceStrings [ "\"" "$" ] [ "\\\"" "\\$" ] s;
    tok = k: p: {
      o = [ "@FACTOR_${k}@" "@SCALE_${k}@" "@ACCEL_${k}@" "@GTK_FONT_${k}@" "@CURSOR_${k}@"
            "@SWAY_${k}@" "@WB_${k}@" "@MAKO_${k}@" "@GHOST_${k}@" "@OSD_${k}@" "@GTKINI_${k}@" ];
      n = [ p.factor (toString p.gtkScale) p.accel (toString p.fonts.gtk) (toString p.cursorSeat)
            (esc (mkSway p)) (esc (mkWaybar p)) (esc (mkMako p)) (esc (mkGhost p)) (esc (mkOsd p)) (esc (mkGtkIni p)) ];
    };
    all = map (k: tok k pres.${k}) [ "720" "1080" "4k" ];
  in {
    executable = true;
    text = builtins.replaceStrings
      (builtins.concatLists (map (x: x.o) all))
      (builtins.concatLists (map (x: x.n) all))
      (builtins.readFile ./sway/scripts/set-res.sh);
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
  xdg.configFile."sway/scripts/pavucontrol-toggle.sh" = {
    executable = true;
    text = builtins.replaceStrings
      [ "@PAV_SCALE@" ]
      [ (toString sizing.display.gtk.pavucontrol) ]
      (builtins.readFile ./sway/scripts/pavucontrol-toggle.sh);
  };

  # swayosd: 2x-scale OSD (volume/brightness popup) — doubles margin/progress/
  # font/icon via the style.css swayosd auto-loads (utils.rs user_style_path).
  # force: set-res.sh rewrites this at runtime (F10/F11/F12) — reset to base
  # without backing up (same .bak-collision reason as sway/config).
  xdg.configFile."swayosd/style.css" = {
    force = true;
    source = ./swayosd/style.css;
  };

  # Waybar config
  # force: set-res.sh rewrites both waybar files at runtime (F10/F11/F12) —
  # reset to base without backing up (see ghostty/config comment).
  xdg.configFile."waybar/config.jsonc" = {
    force = true;
    text = builtins.replaceStrings
      [ "\"icon-size\": 28," "\"spacing\": 10" ]
      [ ("\"icon-size\": " + toString sizing.bar.iconSize + ",")
        ("\"spacing\": " + toString sizing.bar.spacing) ]
      (builtins.readFile ./waybar/config.jsonc);
  };
  xdg.configFile."waybar/style.css" = {
    force = true;
    text = builtins.replaceStrings
      [ "font-family: \"Cousine Nerd Font\", sans-serif;"
        "font-size: 36px;"
        "min-width: 56px;"
        "#282828" "#ebdbb2" "#bdae93" "#83a598" "#cc241d" "#fabd2f"
      ]
      [ ("font-family: \"" + sizing.font.family + "\", sans-serif;")
        ("font-size: " + toString sizing.font.points.waybar + "px;")
        ("min-width: " + toString sizing.bar.fontMinWidth + "px;")
        theme.palette.bg theme.palette.fg theme.palette.fgDim theme.palette.blue theme.palette.red theme.palette.yellow
      ]
      (builtins.readFile ./waybar/style.css);
  };

  # Kanshi config
  xdg.configFile."kanshi/config".source = ./kanshi/config;

  # Global color-scheme + accent (amber) for GTK apps & portals. Cursor theme
  # + size are set HERE (dconf/gsettings) AND in gtk-3.0/settings.ini below,
  # because GTK3 in waybar renders its own hover cursor via settings and was
  # falling back to the tiny black X11 default (it doesn't honor XCURSOR_THEME).
  dconf.settings = {
    "org/gnome/desktop/interface" = {
      color-scheme = "prefer-dark";
      accent-color = "amber";
      font-name = "Cousine Nerd Font 18";   # 4K@scale 1: double the default 11pt
      cursor-theme = theme.cursorTheme;
      cursor-size = sizing.display.cursor.seat;
      # Let GTK4 (pavucontrol) use DARK built-in styles for anything the gruvbox
      # gtk-4.0 theme doesn't cover, so no light leaks.
      gtk-application-prefer-dark-theme = true;
    };
  };

  # force: set-res.sh rewrites gtk-cursor-theme-size at runtime (F10/F11/F12) —
  # reset to base without backing up (see ghostty/config comment).
  xdg.configFile."gtk-3.0/settings.ini" = {
    force = true;
    text = ''
      [Settings]
      gtk-theme-name=${theme.gtkTheme}
      gtk-icon-theme-name=Adwaita
      gtk-cursor-theme-name=${theme.cursorTheme}
      gtk-cursor-theme-size=${toString sizing.display.cursor.seat}
      gtk-application-prefer-dark-theme=1
    '';
  };

  # pavucontrol is a plain GTK4 app (gtkmm4, no libadwaita). GTK4 DOES honor the
  # GTK_THEME env var — but gruvbox-dark ships NO gtk-4.0 theme, so the session's
  # GTK_THEME=gruvbox-dark silently fell back to the light default, and the user
  # gtk.css only patched part of it (the patchy result). FIX: provide a real
  # gruvbox-dark gtk-4.0 theme under ~/.local/share/themes so GTK_THEME loads it
  # as a coherent base. Templated from the theming.nix palette.
  xdg.dataFile."themes/gruvbox-dark/gtk-4.0/gtk.css".text = ''
    /* Gruvbox-dark GTK4 theme (non-libadwaita apps, e.g. pavucontrol). Matches
       the gruvbox look blueman (GTK3) gets from gtk-3.0/settings.ini. */
    window, window.background, .background, .view {
      background-color: ${pal.bg};
      color: ${pal.fg};
    }
    box, grid, .content, stack, list, listview, .list, .rich-list {
      background-color: ${pal.bg};
      color: ${pal.fg};
    }
    headerbar, .titlebar {
      background-color: ${pal.bgAlt};
      color: ${pal.fg};
      border-bottom: 1px solid ${pal.bgDim};
    }
    label { color: ${pal.fg}; }
    .dim-label, label.dim { color: ${pal.fgDim}; }
    button {
      background-color: ${pal.bgAlt};
      border-color: ${pal.bgDim};
      color: ${pal.fg};
      border-radius: 4px;
    }
    button:hover { background-color: ${pal.bgDim}; }
    button:active, button:checked { background-color: ${pal.bgDim}; }
    button.flat { background: transparent; }
    /* pavucontrol tabstrip: GtkStackSwitcher (underline style); notebook fallback */
    .stack-switcher { background-color: ${pal.bgAlt}; padding: 0 8px; }
    .stack-switcher > button {
      background: transparent;
      color: ${pal.fgDim};
      border: none;
      box-shadow: none;
      padding: 8px 20px;                 /* keep tabs readable, not crammed */
      margin: 0 2px;
    }
    .stack-switcher > button:hover { background-color: ${pal.bgDim}; }
    .stack-switcher > button:checked {
      background-color: ${pal.bg};
      color: ${pal.fg};
      box-shadow: inset 0 -2px 0 ${pal.blue};
    }
    notebook, .notebook { background-color: ${pal.bg}; }
    notebook > header { background-color: ${pal.bgAlt}; }
    notebook > header > tabs > tab {
      background-color: ${pal.bgAlt};
      color: ${pal.fgDim};
      border-bottom: 2px solid transparent;
      padding: 8px 20px;                 /* keep tabs readable, not crammed */
      margin: 0 2px;
    }
    notebook > header > tabs > tab:checked {
      background-color: ${pal.bg};
      color: ${pal.fg};
      border-bottom: 2px solid ${pal.blue};
    }
    scale trough { background-color: ${pal.bgDim}; min-height: 8px; border-radius: 4px; }
    scale highlight { background-color: ${pal.blue}; border-radius: 4px; }
    scale slider { background-color: ${pal.fg}; border: 2px solid ${pal.bgDim}; border-radius: 50%; }
    entry, spinbutton {
      background-color: ${pal.bgAlt};
      border-color: ${pal.bgDim};
      color: ${pal.fg};
      caret-color: ${pal.fg};
    }
    entry:focus { border-color: ${pal.blue}; }
    combobox button, combobox { background-color: ${pal.bgAlt}; color: ${pal.fg}; border-color: ${pal.bgDim}; }
    popover, menu, .menu, .popover, dropdown, combobox > window.popover {
      background-color: ${pal.bgAlt};
      color: ${pal.fg};
      border: 1px solid ${pal.bgDim};
    }
    modelbutton { background-color: ${pal.bgAlt}; color: ${pal.fg}; }
    modelbutton:hover { background-color: ${pal.bgDim}; }
    textview, textview text { background-color: ${pal.bg}; color: ${pal.fg}; }
    separator { background-color: ${pal.bgDim}; }
    frame, frame > border { border: 1px solid ${pal.bgDim}; }
    row { background-color: ${pal.bg}; color: ${pal.fg}; }
    row:hover { background-color: ${pal.bgAlt}; }
    scrollbar { background-color: ${pal.bgAlt}; }
    scrollbar slider { background-color: ${pal.bgDim}; }
    check, radio { background-color: ${pal.bgAlt}; color: ${pal.fg}; }
    check:checked, radio:checked { background-color: ${pal.blue}; }
    switch { background-color: ${pal.bgDim}; }
    switch:checked { background-color: ${pal.blue}; }
    progressbar trough { background-color: ${pal.bgDim}; }
    progressbar progress { background-color: ${pal.blue}; }
    tooltip, .osd { background-color: ${pal.bgAlt}; color: ${pal.fg}; border: 1px solid ${pal.bgDim}; }
  '';

  # KDE palette+font (Dolphin): KF6 loads the active palette from a .colors
  # SCHEME FILE ("kdeglobals [General] ColorScheme") - [Colors:*] overrides in
  # kdeglobals were silently ignored (root cause of the still-white Dolphin).
  # GruvboxDark.colors below is the scheme; Size via [General] font.
  home.file.".config/kdeglobals".text = ''
    [General]
    font=Cousine Nerd Font,18,-1,5,50,0,0,0,0,0
    ColorScheme=GruvboxDark
  '';

  home.file.".local/share/color-schemes/GruvboxDark.colors".source =
    ./color-schemes/GruvboxDark.colors;

  # Kvantum: select the gruvbox theme for all non-KDE Qt apps (moonlight, vlc).
  # The theme files come from pkgs.gruvbox-kvantum (systemPackages);
  # kvantum.kvconfig just picks which variant.
  home.file.".config/Kvantum/kvantum.kvconfig".text = ''
    [General]
    theme=Gruvbox-Dark-Brown
  '';

  # Kvantum THEME FILES: symlink the store theme dir into the path Kvantum
  # actually scans (~/.config/Kvantum/, highest priority). Kvantum ignores
  # XDG_DATA_DIRS (nixpkgs#355277), so systemPackages alone is invisible to it
  # - that's why the chrome renders default grey, not brown/green gruvbox.
  #
  # Override only the .kvconfig (colors), not the .svg (chrome shapes). The
  # stock Gruvbox-Dark-Brown [GeneralColors] hard-codes base/alt.base = #282828
  # (no zebra striping) and a translucent brown selection, so it overrides our
  # KColorScheme and the UI melts together. Our patched kvconfig sets the same
  # contrast hierarchy as GruvboxDark.colors (frame #282828 / view #3c3836 /
  # zebra #504945 / aqua selection). The .svg stays a store symlink so we don't
  # vendor a 212KB file into the repo.
  home.file.".config/Kvantum/Gruvbox-Dark-Brown/Gruvbox-Dark-Brown.svg".source =
    "${pkgs.gruvbox-kvantum}/share/Kvantum/Gruvbox-Dark-Brown/Gruvbox-Dark-Brown.svg";
  home.file.".config/Kvantum/Gruvbox-Dark-Brown/Gruvbox-Dark-Brown.kvconfig".source =
    ./kvantum/Gruvbox-Dark-Brown.kvconfig;
}
