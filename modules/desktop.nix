{ pkgs, lib, unstable, ... }:

let
  theme = import ./theming.nix;   # palette / theme names (see file)
  # Same recolored cursor as the home session, so regreet matches (not stock).
  recoloredCursors = import ../home/cursor/theme.nix { inherit pkgs; };
in
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

  # Login: greetd + regreet. ReGreet runs under Cage (minimal Wayland
  # compositor) and launches sway after auth. Default user = hippo.
  programs.regreet = {
    enable = true;
    # Wallpaper installed to /etc/greetd (world-readable) because the greeter
    # user can't read /home/hippo.
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
    cursorTheme.package = recoloredCursors;
  };
  # Greeter wallpaper + a clean regreet.css (greeter user owns /etc/greetd).
  environment.etc."greetd/greeter.jpg".source = ../images/gruvbox-cabin-snow-hill.jpg;

  # swaylock authenticates via PAM (needed for unlock after $mod+Escape / suspend)
  security.pam.services.swaylock = {};

  # dconf backing store (GTK dark-mode preference lives here via home-manager)
  programs.dconf.enable = true;

  # fcitx5 + Simplified Pinyin. waylandFrontend uses native Wayland IM protocol.
  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";
    fcitx5 = {
      waylandFrontend = true;
      addons = [ pkgs.qt6Packages.fcitx5-chinese-addons ];
    };
  };

  # ---- GTK apps: gruvbox ---------------------------------------------------
  # Qt apps are themed system-wide by the `qt` module (configuration.nix).
  # Here we handle the GTK side.
  environment.systemPackages = [
    pkgs.adwaita-icon-theme   # GTK/tray icons
    pkgs.gruvbox-dark-gtk     # GTK apps (blueman, nm-applet, portals) in gruvbox
    pkgs.gruvbox-kvantum      # Kvantum Qt theme (Gruvbox-Dark-Brown)
  ];
  # GTK3/4 apps (blueman, nm-applet, portals): force the gruvbox theme.
  environment.variables.GTK_THEME = theme.gtkTheme;

  # ---- Portals (screenshare/file dialogs under Wayland) ----------------------
  xdg.portal = {
    enable = true;
    wlr.enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
  };

  # ---- Fonts ------------------------------------------------------------------
  fonts.packages = with pkgs; [
  # Cousine Nerd Font: pinned to unstable (3.5.0) for the complete MDI glyph
  # block — 26.05's 3.4.0 is missing a volume glyph.
    unstable.nerd-fonts.cousine
    noto-fonts-cjk-sans           # required for Pinyin IME candidate window / hanzi
    noto-fonts-color-emoji
    dejavu_fonts
    liberation_ttf
  ];

  # HiDPI/fractional scaling lives in home/kanshi/config (output eDP-1 scale 1.5).
  # Sway itself needs nothing special; XWayland runs automatically.
}
