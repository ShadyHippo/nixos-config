# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).

{ config, lib, pkgs, inputs, ... }:

let
  theme  = import ./modules/theming.nix;   # colors/themes → edit to re-theme
  sizing = import ./modules/sizing.nix;    # fonts/scales/layout → edit for other screens
in
{
  # X11/XWayland cursor: sway only themes Wayland clients; libXcursor needs
  # the env vars + the ~/.icons/default inherit set up in home/default.nix.
  environment.variables = {
    XCURSOR_THEME = theme.cursorTheme;
    XCURSOR_SIZE = toString sizing.display.cursor.env;
    # Qt apps render at logical size on 4K@scale 1. Scales Dolphin, Moonlight,
    # kid3, VLC alike. Value lives in modules/sizing.nix (display.qt).
    QT_SCALE_FACTOR = toString sizing.display.qt;
  };

  # gsettings schemas: regreet never sources profile.d, so GSETTINGS_SCHEMA_DIR
  # must be set explicitly for sway's env. This line covers other consumers that
  # do source /etc/profile.
  environment.sessionVariables.XDG_DATA_DIRS =
    [ "${pkgs.gsettings-desktop-schemas}/share/gsettings-schemas/gsettings-desktop-schemas-${pkgs.gsettings-desktop-schemas.version}" ];

  # Qt theming: kvantum for both Qt5 and Qt6, gruvbox palette. The nix qt
  # module sets QT_PLUGIN_PATH for both versions, so ONE QT_STYLE_OVERRIDE=
  # kvantum themes every Qt app. platformTheme="kde" is required: without it,
  # KDE apps (Dolphin) never read the gruvbox color scheme and fall back to
  # Qt's default light palette. kstyle paints chrome, platformTheme drives
  # the color palette — both set together works fine.
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

  services.flatpak.enable = true;

  programs.firefox.enable = false;

  # zsh: sets the login shell + nix dirs on PATH for users whose shell is zsh.
  programs.zsh.enable = true;

  # List packages installed in system profile.
  # You can use https://search.nixos.org/ to find more packages (and options).
  environment.systemPackages = with pkgs; [
    git neovim nil nodejs gcc 
    gnumake jq unzip
    ripgrep fd
    # slurp: pinned to git master for native `-x` crosshair. Patches add font
  # tweaks + cursor hide during snip.
    grim (slurp.overrideAttrs (old: {
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

