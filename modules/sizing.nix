# ─────────────────────────────────────────────────────────────────────────────
# SIZING — ALL display / font / scale / layout numbers for this machine.
#
# This is the ONE BIG FILE for sizing. New machine with a different screen?
# Edit this file, rebuild, done — sway, waybar, mako, ghostty, swayosd and the
# per-app GTK/Qt scaling all follow automatically.
#
# Per-monitor layout (which output where, per location) is NOT here: that lives
# in home/kanshi/config (it maps to YOUR desks). Everything measured in pixels,
# points or a scale factor lives here.
# ─────────────────────────────────────────────────────────────────────────────
{
  # ── FONTS ──
  font = {
    family = "Cousine Nerd Font";
    points = {
      sway     = 22;   # window titles
      waybar   = 36;   # bar labels (x2 = readability on the 4K panel)
      mako     = 16;   # notifications
      ghostty  = 18;   # terminal
      osd      = 20;   # swayosd; rendered at ×display.osd pixels
      fuzzel   = 0;    # not set — fuzzel falls back to its default (0 = skip)
    };
  };

  # ── DISPLAY / SCALING ──
  display = {
    scale  = 1;               # sway output scale — 1 on the 4K panel
    qt     = 1.5;             # global QT_SCALE_FACTOR (Dolphin, moonlight, VLC…). Was 2.0 → too large
    gtk    = {
      # GDK_SCALE per-GTK-app (integers only). IMPORTANT: GTK3's Wayland
      # backend IGNORES GDK_SCALE (verified: same window size either way) —
      # both apps are forced onto XWayland via GDK_BACKEND=x11, where it works.
      blueman     = 2;            # via blueman package wrapper (both launch paths)
      pavucontrol = 2;            # via pavucontrol-toggle.sh launch
    };
    cursor = {
      seat = 64;              # compositor-level cursor px (sway seat, Wayland apps)
      env  = 36;              # XCURSOR_SIZE for X11/GTK apps
    };
    osd    = 2;               # swayosd size multiplier (window, margin, progress, icon, font)
  };

  # ── FLOATING POPUP WINDOWS (anchored top-right under the bar) ──
  popups = {
    pavucontrol = { x = 2310; y = 1310; };              # ×2 → ~1536×808 window: 2310+1536≤3840, 1310+838≤2160
    blueman     = { w = 1060; h = 500; x = 2775; y = 1610; };  # ×2 natural ~1000×1700 → sway resizes to 1060×500, bottom-right (2775+1060≤3840, 1610+500≤2160)
  };

  # ── TOP BAR (waybar) ──
  bar = {
    iconSize     = 28;   # tray icon size px
    spacing      = 10;   # tray icon spacing px
    fontMinWidth = 56;   # workspace pill min-width px (fits "10" at font.points.waybar)
  };

  # ── MISC ──
  titlebarPadding = 4;    # sway titlebar padding px
  makoMargin      = 24;   # notification corner gap px
  makoPadding     = 10;   # notification inner padding px
  makoBorder      = 2;    # notification border px
}