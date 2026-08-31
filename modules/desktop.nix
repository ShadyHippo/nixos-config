{ pkgs, lib, unstable, ... }:

{
  # ---- Sway ------------------------------------------------------------------
  programs.sway = {
    enable = true;
    wrapperFeatures.gtk = true;   # correct GTK theme/xsettings under sway
    extraPackages = with pkgs; [
      waybar                      # status bar
      kanshi                      # monitor hotplug profiles
      fuzzel                      # app launcher ($mod+d)
      swaylock                    # screen lock
      swayidle                    # idle lock/dpms (laptop)
      mako                        # notifications
    ];
  };

  # ---- Login: greetd + regreet (GTK4, Wayland-native, background image) -------
  # ReGreet runs under Cage (a minimal Wayland compositor) as the greeter. The
  # module writes /etc/greetd/regreet.toml from `programs.regreet.settings` and
  # auto-injects the [GTK] section from the theme/font icon opts below.
  # ReGreet ITSELF launches the user's session (sway) after auth — it reads the
  # real desktop session from /usr/share/wayland-sessions, so sway must be a
  # registered session (programs.sway.enable does that). Default user = hippo:
  # it's the only enabled normal user, so it's the dropdown's entry.
  programs.regreet = {
    enable = true;
    # Background = the gruvbox snow-hillside wallpaper. ReGreet runs as the
    # "greeter" user, which can't read /home/hippo, so the image is installed
    # to /etc/greetd (world-readable) via environment.etc below.
    settings = {
      background.path = "/etc/greetd/greeter.jpg";
      background.fit = "Cover";
      appearance.greeting_msg = "Welcome back";
    };
    theme.name = "gruvbox-dark";
    theme.package = pkgs.gruvbox-dark-gtk;
    font.name = "Cousine Nerd Font";
    font.size = 18;
    iconTheme.name = "Adwaita";           # already installed system-wide
    cursorTheme.name = "Bibata-Modern-Classic";
    cursorTheme.package = pkgs.bibata-cursors;
  };
  # Greeter wallpaper + a clean regreet.css (greeter user owns /etc/greetd).
  environment.etc."greetd/greeter.jpg".source = ../images/gruvbox-cabin-snow-hill.jpg;

  # swaylock authenticates via PAM (needed for unlock after $mod+Escape / suspend)
  security.pam.services.swaylock = {};

  # dconf backing store (GTK dark-mode preference lives here via home-manager)
  programs.dconf.enable = true;

  # ---- Input method: fcitx5 + Simplified Pinyin ------------------------------
  # Profile preseeded in home/default.nix -> Ctrl+Super+A toggles EN/Pinyin
  # from first login, no fcitx5-configtool trip. waylandFrontend uses the
  # native Wayland IM protocol (correct under sway, no GTK_IM_MODULE hacks).
  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";
    fcitx5 = {
      waylandFrontend = true;
      addons = [ pkgs.qt6Packages.fcitx5-chinese-addons ];
    };
  };

  # ---- GTK apps: gruvbox ---------------------------------------------------
  # Qt apps are themed system-wide by the `qt` module (configuration.nix):
  # kvantum Gruvbox-Dark for Qt5+Qt6 - one style, no per-app hacks.
  # Here we only handle the GTK side.
  environment.systemPackages = [
    pkgs.adwaita-icon-theme   # GTK/tray icons (fcitx's tray item was broken - no Adwaita theme present)
    pkgs.gruvbox-dark-gtk     # GTK apps (blueman, nm-applet, portals) in gruvbox
    pkgs.gruvbox-kvantum      # Kvantum Qt theme (Gruvbox-Dark-Brown) for non-KDE Qt apps
  ];
  # GTK3/4 apps (blueman, nm-applet, portals): force the gruvbox theme.
  # dconf color-scheme=prefer-dark (home) also set, belt and suspenders.
  environment.variables.GTK_THEME = "gruvbox-dark";

  # ---- Portals (screenshare/file dialogs under Wayland) ----------------------
  xdg.portal = {
    enable = true;
    wlr.enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
  };

  # ---- Fonts ------------------------------------------------------------------
  fonts.packages = with pkgs; [
    # Cousine Nerd Font (terminal/editor font). Pinned to nixos-unstable (3.5.0):
    # the 26.05 branch ships 3.4.0, whose Material Design Icons block stops at
    # \uEFCE — so \uEFCF (a volume glyph) is missing. 3.5.0 fixed the block.
    unstable.nerd-fonts.cousine
    noto-fonts-cjk-sans           # required for Pinyin IME candidate window / hanzi
    noto-fonts-color-emoji
    dejavu_fonts
    liberation_ttf
  ];

  # HiDPI/fractional scaling lives in home/kanshi/config (output eDP-1 scale 1.5).
  # Sway itself needs nothing special; XWayland runs automatically.
}
