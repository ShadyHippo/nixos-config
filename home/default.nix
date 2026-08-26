{ inputs, pkgs, ... }:

{
  home.username = "hippo";
  home.stateVersion = "26.05";

  imports = [
    inputs.zen-browser.homeModules.beta   # provides programs.zen-browser.*
  ];

  # ---------------------------------------------------------------------------
  # Packages (user scope)
  # ---------------------------------------------------------------------------
  home.packages = with pkgs; [
    ghostty                # terminal
    vscode                 # VS Code - swapped to unstable in flake.nix overlay (biweekly MS releases)
    neovim                 # nightly via neovim-nightly-overlay (flake.nix)
    mise                   # dev toolchain manager: runtimes + SOTA agent CLIs
    dolphin-emu            # GameCube/Wii emulator
    qalculate-gtk          # calculator (floating window rule exists for it)
    jq                     # used by sway screenshot/res scripts

    kdePackages.dolphin    # file manager - NAS/SMB/SFTP browsing
    kdePackages.kio-extras # network protocol support for Dolphin (smb:// sftp:// nfs://)
    # Qt dark theme plugin (adwaita-qt6) lives in modules/desktop.nix system scope
  ];

  # GTK side of dark mode: libadwaita follows the portal color-scheme,
  # legacy GTK3 apps take the explicit theme.
  gtk = {
    enable = true;
    gtk3.theme = "Adwaita-dark";
  };
  dconf.settings."org/gnome/desktop/interface" = {
    color-scheme = "prefer-dark";
    gtk-theme = "Adwaita-dark";
  };

  # ---------------------------------------------------------------------------
  # Zen browser + guaranteed uBlock Origin via enterprise policy
  # ---------------------------------------------------------------------------
  programs.zen-browser = {
    enable = true;
    policies = {
      DisableTelemetry = true;
      DisableFirefoxStudies = true;
      DisablePocket = true;
      DontCheckDefaultBrowser = true;
      OfferToSaveLogins = false;
      Extensions.Install = [
        # uBlock Origin, latest from AMO
        "https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/addon.xpi"
      ];
    };
    profiles.default.id = 0;
  };

  # ---------------------------------------------------------------------------
  # Shell (ported from your Debian .bashrc, minus all X11 hacks)
  # ---------------------------------------------------------------------------
  programs.bash = {
    enable = true;
    historySize = 1000;
    historyFileSize = 2000;
    historyControl = [ "ignorespace" "ignoredups" ];   # HISTCONTROL=ignoreboth
    shellAliases = {
      ll = "ls -alF";
      la = "ls -A";
      l = "ls -CF";
      grep = "grep --color=auto";
      fgrep = "fgrep --color=auto";
      egrep = "egrep --color=auto";
      alert = "notify-send --urgency=low -i \"$([ $? = 0 ] && echo terminal || echo error)\" \"$(history|tail -n1|sed -e 's/^\\s*[0-9]\\+\\s*//;s/[;&|]\\s*alert$//')\"";
    };
    initExtra = ''
      # prompt (same as yours)
      PS1="\[\e[32m\]\u\[\e[0m\]:\[\e[34m\]\w\[\e[0m\]$ "

      # PATH additions (guarded - dirs appear when you clone/create them)
      export PATH="$PATH:$HOME/.local/bin/my_scripts"
      export PATH="$PATH:$HOME/.local/bin/AppImages"
      export PATH="$PATH:$HOME/go/bin"

      mkcdir () {
          mkdir -p -- "$1" &&
             cd -P -- "$1"
      }

      # Optional tool envs - activate only if present
      [ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"
      [ -f "$HOME/.deno/env" ] && . "$HOME/.deno/env"
    '';
  };

  home.sessionVariables = {
    ANDROID_HOME = "$HOME/Android/Sdk";
  };
  # Android SDK subdirs, only if the SDK exists
  programs.bash.profileExtra = ''
    if [ -d "$HOME/Android/Sdk" ]; then
      export PATH="$PATH:$ANDROID_HOME/emulator:$ANDROID_HOME/platform-tools"
    fi
  '';

  # readline: your tab-completion behavior (menu cycling)
  home.file.".inputrc".text = ''
    set completion-ignore-case on
    set show-all-if-ambiguous on
    set menu-complete-display-prefix on
    "\t": menu-complete
    "\e[Z": menu-complete-backward
  '';

  # ---------------------------------------------------------------------------
  # Dev tools
  # ---------------------------------------------------------------------------
  programs.mise.enable = true;

  # mise-managed global tools (SOTA lane). Language runtimes get added here by
  # 'mise use -g <tool>@<version>' as you need them; this file is the source of
  # truth so a fresh machine reproduces the set.
  # Hot-pink cursor: possible via oreo-cursors-plus (in nixpkgs) with a custom
  # cursorsConf override — it regenerates the theme in any color you specify,
  # but needs a derivation tweak + upstream conf format. A later project.
  # Skeleton for ANY cursor theme once chosen:
  # home.pointerCursor = {
  #   package = pkgs.phinger-cursors;        # or your pink build
  #   name = "phinger-cursors-light";
  #   size = 32;                             # logical px at scale 1.5 ≈ your old 48
  # };

  xdg.configFile."mise/config.toml".text = ''
    [tools]
    opencode = "latest"
    maki = "ubi:tontinton/maki"   # static musl binary from GitHub releases
    deno = "latest"               # yt-dlp uses deno as JS runtime for some extractors (YouTube signatures etc.)
    # node = "lts"                # uncomment if something else needs node specifically
    # go = "latest"
    # python = "3.12"
  '';

  programs.git = {
    enable = true;
    userName = "ShadyHippo";
    userEmail = "tim.vandyke123@gmail.com";
    extraConfig = {
      push.autoSetupRemote = true;
      credential."https://github.com".helper = "!${pkgs.gh}/bin/gh auth git-credential";
      credential."https://gist.github.com".helper = "!${pkgs.gh}/bin/gh auth git-credential";
    };
  };
  programs.gh.enable = true;

  programs.vscode.enable = true;

  # ---------------------------------------------------------------------------
  # fcitx5: English + Simplified Pinyin, toggled with Ctrl+Super+A
  # (preseeded so no trip to fcitx5-configtool needed)
  # ---------------------------------------------------------------------------
  xdg.configFile."fcitx5/profile".text = ''
    [Groups/0]
    Name=Default
    Default Layout=us
    DefaultIM=pinyin

    [Groups/0/Items/0]
    Name=keyboard-us

    [Groups/0/Items/1]
    Name=pinyin

    [GroupOrder]
    0=Default
  '';

  xdg.configFile."fcitx5/config".text = ''
    [Hotkey]
    TriggerKeys=Control+Super+a
    EnumerateWithTriggerKeys=True
  '';

  # ---------------------------------------------------------------------------
  # Dolphin: Fire Emblem Path of Radiance texture pack setup
  # ---------------------------------------------------------------------------
  xdg.configFile."dolphin-emu/GFX.ini".text = ''
    [Enhancements]
    HiresTextures = True
  '';

  xdg.configFile."dolphin-emu/GameSettings/GFEM01.ini".text = ''
    # Fire Emblem: Path of Radiance (US - matches your .iso)
    [Enhancements]
    HiresTextures = True
  '';

  # Your pack master lives in ~/Games/Dolphin_Textures with EU-style IDs:
  #   GFEE01 = PoR (your disc is USA/GFEM01 -> RENAME GFEE01->GFEM01 when copying!)
  #   GLME01 = Luigi's Mansion (matches your USA .gcm, use as-is)
  home.file.".local/share/dolphin-emu/Load/Textures/README_COPY_PACK_HERE.txt".text = ''
    Texture pack install notes (from the great migration):

      cp -r ~/Games/Dolphin_Textures/Textures/GLME01 ~/.local/share/dolphin-emu/Load/Textures/

      # PoR: your disc is USA but the pack folder says GFEE01 (EU).
      # Rename while copying or Dolphin won't match it:
      cp -r ~/Games/Dolphin_Textures/Textures/GFEE01 \
            ~/.local/share/dolphin-emu/Load/Textures/GFEM01

    Verify the ID shown in Dolphin's title bar matches the folder name.
  '';

  # ---------------------------------------------------------------------------
  # Dotfiles (real files next to this one, easier to edit than heredocs)
  # ---------------------------------------------------------------------------
  xdg.configFile."sway/config".source = ./sway/config;
  xdg.configFile."sway/scripts/set-res.sh" = {
    source = ./sway/scripts/set-res.sh;
    executable = true;
  };
  xdg.configFile."sway/scripts/screenshot.sh" = {
    source = ./sway/scripts/screenshot.sh;
    executable = true;
  };
  xdg.configFile."kanshi/config".source = ./kanshi/config;
  xdg.configFile."waybar/config.jsonc".source = ./waybar/config.jsonc;
  xdg.configFile."waybar/style.css".source = ./waybar/style.css;

  xdg.configFile."ghostty/config".text = ''
    theme = GruvboxDark
    font-family = Cousine Nerd Font
    font-size = 14
  '';

  # imv: replacement for the old feh flags in my_scripts/img
  # (feh --force-aliasing -g 1250x2000 --auto-zoom)
  xdg.configFile."imv/config".text = ''
    width = 1250
    height = 2000
  '';
}
