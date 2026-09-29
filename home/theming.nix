# Theming: GTK3/GTK4/libadwaita, Qt (Kvantum), KDE color scheme, cursors.
# Palette/theme names come from machine/theme.nix; the generated CSS files are
# machine/gtk4-theme.nix and machine/gtk4-libadwaita.nix.
{ pkgs, ... }:

let
  theme = import ../machine/theme.nix;
  pal   = theme.palette;
  # Recolored Bibata cursor theme shared with regreet (modules/desktop.nix),
  # so sway session and greeter show the same cursor.
  recoloredCursors = import ./cursor/theme.nix { inherit pkgs; colors = theme.palette; };
  # GTK4 gruvbox CSS for non-libadwaita GTK4 apps (pavucontrol 6.x).
  gtk4css = import ../machine/gtk4-theme.nix theme;
  # libadwaita color overrides for GTK4 libadwaita apps (Kooha, GNOME apps).
  adwaitaCss = import ../machine/gtk4-libadwaita.nix theme;
in
{
  # Recolored Bibata from the single built package shared with regreet.
  home.file.".icons/Bibata-Modern-Classic".source =
    "${recoloredCursors}/share/icons/Bibata-Modern-Classic";

  # X11 apps (Electron on XWayland) resolve cursor via libXcursor —
  # ~/.icons/default must exist and inherit.
  home.file.".icons/default/index.theme".text = ''
    [Icon Theme]
    Inherits=${theme.cursorTheme}
  '';

  # Accent + legacy prefer-dark key that the `gtk` module does NOT write
  # (module owns color-scheme/font/cursor/theme via dconf below).
  dconf.settings = {
    "org/gnome/desktop/interface" = {
      accent-color = "amber";
      gtk-application-prefer-dark-theme = true;
    };
  };

  # GTK theming via the home-manager `gtk` module — the documented way.
  # It generates gtk-3.0/settings.ini AND mirrors the same keys into dconf
  # (org.gnome.desktop.interface), so apps launched with a clean env (systemd
  # user services, e.g. easyeffects) get the theme too; the theme package is
  # also installed to the user profile (~/.nix-profile/share on XDG_DATA_DIRS).
  # NOTE: set-res.sh still force-rewrites settings.ini at runtime (preset
  # switches) — that behaviour is unchanged.
  gtk = {
    enable = true;
    colorScheme = "dark";   # → gtk-application-prefer-dark-theme + prefer-dark
    font = {
      name = theme.font.family;
      size = 18;
    };
    theme = {
      name = theme.gtkTheme;
      package = pkgs.gruvbox-dark-gtk;
    };
    iconTheme = {
      name = "Adwaita";
      package = pkgs.adwaita-icon-theme;
    };
    cursorTheme = {
      name = theme.cursorTheme;
      package = recoloredCursors;
      size = theme.display.cursor.seat;
    };
    # GTK4: stateVersion 26.05 keeps gtk4.theme null (libadwaita defaults).
  };

  # GTK4 gruvbox css for non-libadwaita GTK4 apps (pavucontrol 6.x): consumed
  # via GTK_THEME=gruvbox-dark → ~/.local/share/themes/gruvbox-dark/gtk-4.0/.
  # Don't remove — pavucontrol does not go through gtk3 settings/dconf at all.
  xdg.dataFile."themes/gruvbox-dark/gtk-4.0/gtk.css".text = gtk4css;

  # libadwaita apps (Kooha, GNOME apps) ignore GTK_THEME and paint from their
  # own stylesheet; the supported override is the USER stylesheet, loaded at
  # higher priority than libadwaita's provider. libadwaita 1.4+ reads these as
  # CSS custom properties (not @define-color). Generated from the palette.
  xdg.configFile."gtk-4.0/gtk.css".text = adwaitaCss;

  # Belt-and-suspenders: the gtk module resolves the theme via the user
  # profile (XDG_DATA_DIRS). A ~/.themes copy additionally covers contexts
  # whose env may lack that path (some systemd user services) — GTK3 always
  # checks ~/.themes first, keyed only on $HOME.
  home.file.".themes/gruvbox-dark".source =
    "${pkgs.gruvbox-dark-gtk}/share/themes/gruvbox-dark";

  # KDE palette+font (Dolphin) + KColorScheme source for Kirigami apps
  # (bluejay). The Qt platform theme (kde) resolves the .colors SCHEME FILE
  # via [General] ColorScheme for QWidgets palettes — but raw KColorScheme,
  # which drives Kirigami/QML theming, reads the [Colors:*] groups STRAIGHT
  # from kdeglobals and falls back to hardcoded Breeze Light when they're
  # absent (that was the white bluejay). So inline the scheme groups here;
  # the .colors file keeps the name-resolution side. Single source of truth.
  home.file.".config/kdeglobals".text = ''
    [General]
    font=${theme.font.family},18,-1,5,50,0,0,0,0,0
    ColorScheme=GruvboxDark
  '' + builtins.readFile ./color-schemes/GruvboxDark.colors;

  home.file.".local/share/color-schemes/GruvboxDark.colors".source =
    ./color-schemes/GruvboxDark.colors;

  # Kvantum: select the gruvbox theme for all non-KDE Qt apps.
  home.file.".config/Kvantum/kvantum.kvconfig".text = ''
    [General]
    theme=${theme.qtTheme}
  '';

  # Kvantum theme: symlink the store .svg + patched .kvconfig into
  # ~/.config/Kvantum/ (Kvantum ignores XDG_DATA_DIRS, nixpkgs#355277).
  home.file.".config/Kvantum/Gruvbox-Dark-Brown/Gruvbox-Dark-Brown.svg".source =
    "${pkgs.gruvbox-kvantum}/share/Kvantum/Gruvbox-Dark-Brown/Gruvbox-Dark-Brown.svg";
  home.file.".config/Kvantum/Gruvbox-Dark-Brown/Gruvbox-Dark-Brown.kvconfig".source =
    ./kvantum/Gruvbox-Dark-Brown.kvconfig;
}
