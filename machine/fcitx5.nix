# ─────────────────────────────────────────────────────────────────────────────
# FCITX5 — Simplified Chinese Pinyin IME.
#
# Not a common need — this whole file is one trimmable unit. To remove the IME:
#   1. delete this file
#   2. remove `./machine/fcitx5.nix` from flake.nix's modules list
#
# Everything the IME touches lives here: the system input-method framework,
# the CJK font (only needed for hanzi/candidate rendering), the user configs,
# and the sway autostart + toggle keybind ($mod+Shift+t).
# ─────────────────────────────────────────────────────────────────────────────
{ pkgs, ... }:

let
  identity = import ./identity.nix;
in
{
  # System side: fcitx5 + Simplified Pinyin. waylandFrontend uses the native
  # Wayland IM protocol (works in every app, incl. Electron).
  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";
    fcitx5 = {
      waylandFrontend = true;
      addons = [ pkgs.qt6Packages.fcitx5-chinese-addons ];
    };
  };

  # CJK font — required for the Pinyin candidate window / hanzi glyphs.
  fonts.packages = [ pkgs.noto-fonts-cjk-sans ];

  # User side: preseeded IMs + trigger keys + UI font, and the sway wiring.
  home-manager.users.${identity.username} = {
    # fcitx5: preseed IMs (keyboard-us + Pinyin) + trigger keys. Without this
    # the tray shows "input" and clicking it does nothing.
    xdg.configFile."fcitx5/profile".text = ''
      [Profile]
      EnabledIMList=pinyin:False,keyboard-us:True

      [Groups/0]
      Name=Default
      Default Layout=us
      DefaultIM=keyboard-us

      [Groups/0/Items/0]
      Name=keyboard-us
      Layout=

      [Groups/0/Items/1]
      Name=pinyin
      Layout=

      [GroupOrder]
      0=Default
    '';

    # TriggerKeys = Super+Shift+t. ShareInputState=All makes IM state global.
    xdg.configFile."fcitx5/config".text = ''
      [Hotkey]
      TriggerKeys=Super+Shift+t

      [Behavior]
      ShareInputState=All
    '';

    # fcitx5 UI font — doubled from default 10pt for 4K@scale 1.
    xdg.configFile."fcitx5/conf/classicui.conf".text = ''
      Font=Sans 24
      MenuFont=Sans 24
      TrayFont=Sans Bold 24
    '';

    # Sway autostart + global EN/Pinyin toggle. extraConfig appends (sway is
    # last-wins), so these join the end of the config — same as anything else.
    # $mod+Shift+t works in EVERY app: sway intercepts before the app's IME
    # protocol, so no VS Code/Electron blind spot.
    wayland.windowManager.sway.extraConfig = ''
      exec fcitx5 -d --replace
      bindsym $mod+Shift+t exec fcitx5-remote -t
    '';
  };
}