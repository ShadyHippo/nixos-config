# ─────────────────────────────────────────────────────────────────────────────
# THEME — every color / font / scale / layout decision in one place.
#
# New machine? Want a different look? Edit THIS file, then rebuild. Sway,
# waybar, mako, ghostty, the recolored cursor and GTK/Qt env all follow
# automatically.
#
# Per-monitor layout (which output where) is NOT here: that's home/kanshi/config.
# Runtime resolution presets ($mod+F10/11/12) are NOT here: that's resolution.nix.
# ─────────────────────────────────────────────────────────────────────────────
{
  # ── Gruvbox palette + the hot-pink signature accent ──
  # Hexes only; every consumer (sway, waybar, mako, cursors) reads from here.
  palette = {
    bg      = "#282828";   # window / panel background
    bgAlt   = "#3c3836";   # unfocused windows, alt surfaces
    bgDim   = "#665c54";   # inactive titlebars, dim borders
    fg      = "#ebdbb2";   # primary text
    fgDim   = "#bdae93";   # secondary text
    gray    = "#928374";   # muted / comments
    red     = "#cc241d";   # errors, urgent
    green   = "#b8bb26";   # cursor outline, success
    yellow  = "#fabd2f";   # warnings
    blue    = "#83a598";   # focused borders
    purple  = "#d3869b";
    aqua    = "#8ec07c";
    orange  = "#fe8019";   # git branch etc.
    accent  = "#ff2b6d";   # hot pink — cursors, prompt arrow, session pop
  };

  # ── GTK / Qt theme names (packages installed in modules/desktop.nix) ──
  gtkTheme = "gruvbox-dark";
  qtTheme  = "Gruvbox-Dark-Brown";

  # ── Cursor theme name (package rebuilt recolored — home/cursor/theme.nix) ──
  cursorTheme = "Bibata-Modern-Classic";

  # ── Wallpaper (file installed by home-manager into the user's home) ──
  wallpaper = "/home/${(import ./identity.nix).username}/.local/share/backgrounds/gruvbox-astronaut-4k.png";

  # ── FONTS ──
  font = {
    family = "Cousine Nerd Font";
    points = {
      sway     = 22;   # window titles
      waybar   = 36;   # bar labels
      mako     = 18;   # notifications
      ghostty  = 18;   # terminal
      osd      = 20;   # swayosd; rendered at ×display.osd pixels
      fuzzel   = 0;    # not set — fuzzel falls back to its default (0 = skip)
    };
  };

  # ── DISPLAY / SCALING ──
  display = {
    scale  = 1;               # sway output scale
    qt     = 1.5;             # global QT_SCALE_FACTOR (Dolphin, Moonlight, VLC…)
    gtk    = {
      # GTK3's Wayland backend ignores GDK_SCALE — pavucontrol is forced onto
      # XWayland via GDK_BACKEND=x11, where it works. (bluejay is Qt6: the
      # global QT_SCALE_FACTOR above already scales it.)
      pavucontrol = 2;        # fallback in pavucontrol-toggle.sh (default = 4K)
    };
    cursor = {
      seat = 64;              # compositor-level cursor px (sway seat)
      env  = 36;              # XCURSOR_SIZE for X11/GTK apps
    };
    osd    = 2;               # swayosd size multiplier
  };

  # ── FLOATING POPUP WINDOWS (anchored under the bar) ──
  popups = {
    pavucontrol = { x = 2310; y = 1310; };
    # bluejay runs at the global QT_SCALE_FACTOR 1.5, so physical size =
    # logical × 1.5. 4K-preset values below; retune with $mod+r if needed.
    # Same bottom/right anchor as the old 800x380 popup (3575, 2110).
    bluejay     = { w = 1600; h = 760; x = 2235; y = 1350; };
  };

  # ── TOP BAR (waybar) ──
  bar = {
    iconSize     = 28;   # tray icon size px
    spacing      = 10;   # tray icon spacing px
    fontMinWidth = 56;   # workspace pill min-width px
  };

  # ── MISC ──
  titlebarPadding = 4;    # sway titlebar padding px
  makoMargin      = 24;   # notification corner gap px
  makoPadding     = 10;   # notification inner padding px
  makoBorder      = 2;    # notification border px
}
