# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).

{ config, lib, pkgs, inputs, ... }:

let
  theme  = import ./modules/theming.nix;   # colors/themes → edit to re-theme
  sizing = import ./modules/sizing.nix;    # fonts/scales/layout → edit for other screens
in
{
  # Reach the X11/XWayland apps (Discord/Signal) too: sway's seat only themes
  # Wayland clients; libXcursor needs the env vars + the ~/.icons/default
  # inherit set up in home/default.nix.
  environment.variables = {
    XCURSOR_THEME = theme.cursorTheme;
    XCURSOR_SIZE = toString sizing.display.cursor.env;
    # 4K@scale 1: Qt apps otherwise render at logical size. Global 1.5x (this
    # replaces the old per-app moonlight QT_SCALE_FACTOR wrapper - one env var
    # scales Dolphin, moonlight, kid3 and vlc alike). 2x was too large; 1.5x is
    # the sweet spot. Value lives in modules/sizing.nix (display.qt).
    QT_SCALE_FACTOR = toString sizing.display.qt;
  };

  # gsettings schemas for login shells: the nix profile injects the per-package
  # XDG_DATA_DIRS entries when a profile.d is sourced, but sway's session
  # (regreet) never sources it — set-res.sh handles sway's env via
  # GSETTINGS_SCHEMA_DIR instead. This line just makes the schemas reachable
  # for any other consumer that does source /etc/profile.
  environment.sessionVariables.XDG_DATA_DIRS =
    [ "${pkgs.gsettings-desktop-schemas}/share/gsettings-schemas/gsettings-desktop-schemas-${pkgs.gsettings-desktop-schemas.version}" ];

  # ---- Qt theming (kvantum for BOTH Qt5 & Qt6, gruvbox) ------------------
  # The nix `qt` module installs qtstyleplugin-kvantum for both Qt5 and Qt6
  # (theme engine available in BOTH versions - the cross-version trick) and
  # sets QT_PLUGIN_PATH for qt-5 AND qt-6 plugin dirs, so ONE
  # QT_STYLE_OVERRIDE=kvantum themes every Qt app regardless of version
  # (vlc=Qt5, moonlight/Dolphin=Qt6). Gruvbox-Dark-Brown theme is selected in
  # ~/.config/Kvantum/kvantum.kvconfig (home/default.nix). Kvantum paints all
  # widgets from its own gruvbox theme - no per-app carve-outs needed.
  #
  # platformTheme="kde" is REQUIRED: without a platform theme, KDE apps never
  # read ~/.local/share/color-schemes/GruvboxDark.colors, so their PALETTE
  # (file-list background, alternate rows, status bar, text) falls back to
  # Qt's default LIGHT scheme -> white zebra stripes and unreadable text.
  # platformTheme=kde sets QT_QPA_PLATFORMTHEME=kde and pulls in
  # kdePackages.plasma-integration (the KDE platform-theme plugin), which makes
  # Dolphin & friends load the gruvbox color scheme + kdeglobals. kstyle paints
  # chrome (kvantum), platformTheme drives the palette (color scheme). Both can
  # be set together (module only asserts gnome->gnomeStyles; kde+kvantum is free).
  qt = {
    enable = true;
    platformTheme = "kde";
    style = "kvantum";
  };

  networking.hostName = "hippo-xps"; # Define your hostname.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # 32px Terminus — stock 16px is unusable on the 4K panel.
  console = {
    font = "${pkgs.terminus_font}/share/consolefonts/ter-132n.psf.gz";
    keyMap = "us";
    # useXkbConfig = true; # use xkb.options in tty.
  };

  # Enable CUPS to print documents.
  # services.printing.enable = true;

  programs.firefox.enable = false;

  # zsh: sets the login shell + nix dirs on PATH for users whose shell is zsh.
  programs.zsh.enable = true;

  # List packages installed in system profile.
  # You can use https://search.nixos.org/ to find more packages (and options).
  environment.systemPackages = with pkgs; [
    git neovim nil nodejs gcc 
    gnumake jq unzip
    ripgrep fd
    grim (slurp.overrideAttrs (old: {
      # slurp git master (pinned rev): native `-x` crosshair that TRACKS pre-click
      # (the seat_set_outputs_dirty fix landed upstream; nixpkgs still ships 1.5.0
      # without it). patches/slurp-tweaks.patch = our readout tweaks (font 48,
      # offsets 24/48) + hide the cursor during the snip (NULL wl_pointer cursor,
      # restored automatically on exit). Hot pink comes from -c in screenshot.sh.
      src = pkgs.fetchFromGitHub {
        owner = "emersion";
        repo = "slurp";
        rev = "a3998d3ec79fbd85b81911f43010466b032ed0d9";
        sha256 = "0lhhgxx2w09h18n3ls624kmmcrljwkqrb8nsa6f8s1rk7zh5izpm";
      };
      patches = (old.patches or []) ++ [ ./patches/slurp-tweaks.patch ];
    })) wl-clipboard 
    mako brightnessctl
    wget curl pciutils usbutils 
    lshw pavucontrol blueman 
    playerctl libnotify
    tree htop btop file tldr
    cifs-utils samba
    mpv vlc ffmpeg

    kdePackages.dolphin
    kdePackages.kio
    kdePackages.kio-fuse
    kdePackages.kio-extras
    kdePackages.qtsvg
  ] ++ [
    inputs.zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.default
  ];

  environment.etc."xdg/menus/applications.menu".source = "${pkgs.kdePackages.plasma-workspace}/etc/xdg/menus/plasma-applications.menu";

  # Zen is the default browser for everything.
  xdg.mime.defaultApplications = {
    "text/html" = "zen.desktop";
    "application/xhtml+xml" = "zen.desktop";
    "x-scheme-handler/http" = "zen.desktop";
    "x-scheme-handler/https" = "zen.desktop";
    "x-scheme-handler/about" = "zen.desktop";
    "x-scheme-handler/unknown" = "zen.desktop";
  };

  # Prefer dark color scheme app-wide (freedesktop color-scheme accent).
  xdg.portal.config.common.default = "gtk";

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # Copy the NixOS configuration file and link it from the resulting system
  # (/run/current-system/configuration.nix). This is useful in case you
  # accidentally delete configuration.nix.
  # system.copySystemConfiguration = true;


}

