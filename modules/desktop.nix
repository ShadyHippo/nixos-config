{ pkgs, lib, ... }:

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

  # ---- Login: greetd + tuigreet (lightweight, wayland-native) -----------------
  services.greetd = {
    enable = true;
    settings.default_session.command = "${lib.getExe pkgs.tuigreet} --time --asterisks --cmd sway";
  };

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
      addons = [ pkgs.fcitx5-chinese-addons ];
    };
  };

  # ---- Qt dark theming (Dolphin FM + dolphin-emu, without Plasma) ------------
  # A real QStyle via adwaita-qt6 - not a qt5ct/kvantum config-file hack.
  # Vars set system-wide so they reach the session however sway gets launched.
  # Covers both dolphins ("not burn my eyes", per your old bashrc).
  environment.systemPackages = [ pkgs.adwaita-qt6 ];
  environment.variables.QT_STYLE_OVERRIDE = "adwaita-dark";
  # where Qt finds the style plugin (systemPackages merge their lib/ here)
  environment.variables.QT_PLUGIN_PATH = [ "/run/current-system/sw/lib/qt-6/plugins" ];

  # ---- Portals (screenshare/file dialogs under Wayland) ----------------------
  xdg.portal = {
    enable = true;
    wlr.enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
  };

  # ---- Fonts ------------------------------------------------------------------
  fonts.packages = with pkgs; [
    nerd-fonts.cousine            # Cousine Nerd Font (your terminal/editor font)
    noto-fonts-cjk-sans           # required for Pinyin IME candidate window / hanzi
    noto-fonts-emoji
    dejavu_fonts
    liberation_ttf
  ];

  # HiDPI/fractional scaling lives in home/kanshi/config (output eDP-1 scale 1.5).
  # Sway itself needs nothing special; XWayland runs automatically.
}
