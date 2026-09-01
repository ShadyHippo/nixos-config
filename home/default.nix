{ pkgs, unstable, ... }:

let
  # Recolored Bibata cursor theme shared by the sway session and regreet.
  recoloredCursors = import ./cursor/theme.nix { inherit pkgs; };
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

    starship                 # prompt (config: ~/.config/starship.toml)

    # image tooling — convert (imagemagick) + cwebp (libwebp): required by
    # scripts/build_db.py for thumbnail resize (--thumb 128) + WebP encoding
    imagemagick
    libwebp
  ];

  # Cursor: bigger + a real theme (default is a tiny X cursor)
  home.sessionVariables = {
    XCURSOR_SIZE = "36";
    XCURSOR_THEME = "Bibata-Modern-Classic";
  };

  # Recolored Bibata from the single built package shared with regreet, so the
  # sway session and the greeter show the SAME hot-pink cursor. home.file
  # shadows the store copy; the recolor colors are in home/cursor/theme.nix.
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

  home.file.".config/ghostty/config".source = ./ghostty/config;

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
  xdg.configFile."mako/config".source = ./mako/config;

  # fastfetch (neofetch drop-in): no config override — uses pure defaults,
  # which auto-detects + prints the NixOS logo. My earlier custom config
  # disabled the logo with "type":"none". Remove it to get the logo back.

  # pinyin ready at login (Ctrl+Super+A)
  programs.bash.enable = true;

  # ---------------------------------------------------------------------------
  # Shell: zsh — fzf-tab fuzzy completion on <Tab>, Starship prompt
  # ---------------------------------------------------------------------------
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion = {
      enable = true;
      highlight = "fg=#928374";   # gruvbox gray suggestion
    };
    syntaxHighlighting.enable = true;
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

      # ---- Starship prompt ----
      eval "$(starship init zsh)"
    '';
  };

  # Starship prompt config (deployed free from home-manager's TOML generator so
  # the escaped bracket format string round-trips exactly).
  xdg.configFile."starship.toml".source = ./starship.toml;

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
    extraConfig = builtins.readFile ./sway/config + ''

      # Auto-float dialogs and popups (Dolphin file transfers, file pickers, etc.)
      for_window [window_role="pop-up"] floating enable
      for_window [window_role="dialog"] floating enable
    '';
  };

  # Scripts referenced from sway config
  xdg.configFile."sway/scripts/screenshot.sh" = {
    source = ./sway/scripts/screenshot.sh;
    executable = true;
  };
  xdg.configFile."sway/scripts/set-res.sh" = {
    source = ./sway/scripts/set-res.sh;
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
  xdg.configFile."sway/scripts/pavucontrol-toggle.sh" = {
    source = ./sway/scripts/pavucontrol-toggle.sh;
    executable = true;
  };

  # swayosd: 2x-scale OSD (volume/brightness popup) — doubles margin/progress/
  # font/icon via the style.css swayosd auto-loads (utils.rs user_style_path).
  xdg.configFile."swayosd/style.css".source = ./swayosd/style.css;

  # Waybar config
  xdg.configFile."waybar/config.jsonc".source = ./waybar/config.jsonc;
  xdg.configFile."waybar/style.css".source = ./waybar/style.css;

  # Kanshi config
  xdg.configFile."kanshi/config".source = ./kanshi/config;

  # Global color-scheme + accent (amber) for GTK apps & portals.
  dconf.settings = {
    "org/gnome/desktop/interface" = {
      color-scheme = "prefer-dark";
      accent-color = "amber";
      font-name = "Cousine Nerd Font 18";   # 4K@scale 1: double the default 11pt
    };
  };

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
