{ config, lib, pkgs, inputs, ... }:

let
  theme = import ./machine/theme.nix;   # colors/fonts/scales (see machine/)
  identity = import ./machine/identity.nix;
in
{
  # X11/XWayland cursor: sway only themes Wayland clients; libXcursor needs
  # the env vars + the ~/.icons/default inherit set up in home/default.nix.
  environment.variables = {
    XCURSOR_THEME = theme.cursorTheme;
    XCURSOR_SIZE = toString theme.display.cursor.env;
    # Qt apps render at logical size on 4K@scale 1. Scales Dolphin, Moonlight,
    # kid3, VLC alike. Value lives in machine/theme.nix (display.qt).
    QT_SCALE_FACTOR = toString theme.display.qt;
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

  networking.hostName = identity.hostname;

  # 32px Terminus — stock 16px is unusable on the 4K panel.
  console = {
    font = "${pkgs.terminus_font}/share/consolefonts/ter-132n.psf.gz";
    keyMap = "us";
  };

  services.flatpak.enable = true;

  # zsh: sets the login shell + nix dirs on PATH for users whose shell is zsh.
  programs.zsh.enable = true;

  # C++ compile cache — quickshell patch rebuilds were cold 3-4 min (~600 Qt
  # TUs, no incrementality in Nix); warm rebuilds should drop to ~1 min.
  # enable creates /var/cache/ccache via tmpfiles (root:nixbld 0770) and the
  # nix-ccache stats wrapper. The module does NOT add the cache dir to the
  # build sandbox — without the nix.settings line below every ccache'd build
  # fails loudly (ccache can't create its dir inside the sandbox).
  # CCACHE_SLOPPINESS must add pch_defines,time_macros on top of the module's
  # random_seed: quickshell is PCH-heavy (cmake/pch.cmake) and ccache can't
  # hash PCH-using TUs without them → near-zero hit rate.
  # BOOTSTRAP: the dir + sandbox mount only land at ACTIVATION, but the
  # build runs BEFORE that — so the very first switch must pre-create the
  # dir and pass the sandbox path explicitly (root is trusted, daemon
  # honors --option):
  #   sudo mkdir -m0770 /var/cache/ccache && sudo chown root:nixbld /var/cache/ccache
  #   sudo nixos-rebuild switch --flake .#hippo-xps --option extra-sandbox-paths /var/cache/ccache
  # After that activation plain switches work (tmpfiles + nix.conf persist).
  programs.ccache.enable = true;
  nix.settings.extra-sandbox-paths = [ config.programs.ccache.cacheDir ];

  nixpkgs.overlays = [
    (final: prev: {
      ccacheWrapper = prev.ccacheWrapper.override (old: {
        extraConfig = old.extraConfig + ''
          export CCACHE_DIR="${config.programs.ccache.cacheDir}"
          export CCACHE_COMPRESS=1
          export CCACHE_SLOPPINESS="random_seed,pch_defines,time_macros"
          export CCACHE_UMASK=007
        '';
      });
      # quickshell with ccache: first build cold (populates the cache),
      # subsequent rebuilds only compile TUs the patch actually touched.
      quickshell = prev.quickshell.override { stdenv = final.ccacheStdenv; };
    })
  ];

  # List packages installed in system profile.
  # NOTE: base.nix and home/default.nix also install packages. This list is
  # for things that belong at system scope only (build tools, CLI, browsers).
  environment.systemPackages = with pkgs; [
    neovim nil nodejs gcc
    gnumake unzip
    ripgrep fd
  # slurp: pinned to a specific commit for the native `-x` crosshair + cursor
  # hide during snip. The patches in ./patches/ add font tweaks. Without the
  # pin, the patches fail to apply (upstream changed the source layout).
    grim (slurp.overrideAttrs (old: {
      src = pkgs.fetchFromGitHub {
        owner = "emersion";
        repo = "slurp";
        rev = "a3998d3ec79fbd85b81911f43010466b032ed0d9";
        sha256 = "0lhhgxx2w09h18n3ls624kmmcrljwkqrb8nsa6f8s1rk7zh5izpm";
      };
      patches = (old.patches or []) ++ [ ./patches/slurp-tweaks.patch ];
    }))
    tree file tldr
    cifs-utils samba

    # BatteryScope native deps (GTK4/libadwaita/SQLite) — mise builds the
    # Rust binary; Nix supplies the C libraries at build time.
    pkg-config gtk4 libadwaita graphene gdk-pixbuf cairo pango harfbuzz dbus sqlite

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

}

