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
rec {
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

  # ── RUNTIME PRESETS ($mod+F10/11/12 → 720p/1080p/4K) ──
  # The panel physically upscales the 720p/1080p framebuffers to 3840×2160
  # (the iGPU composites at the low res, the fixed scaler upscales), so every
  # framebuffer px is 2 or 3 physical px. Dimensions (cursors, accel, popup
  # offsets, bar/mako/OSD sizes) are halved/thirded so they stay physically
  # identical; FONTS are user-tuned per preset instead — see the note below.
  # set-res.sh is built from THIS table at config time. `accel` is the only
  # tuned (non-derived) value — libinput's mapping isn't linear, tweak per
  # preset. Round-half-up via integer math (no builtins.round needed). NOTE:
  # fonts are deliberately NOT half/thirded anymore — the user found the
  # halved/thirded text too small/grainy on the upscaled panel, so fonts use
  # user-tuned ratios (1080p = 11pt, 720p = 10pt ghostty = ×11/18, ×10/18 of
  # the 4K baseline). Physical size is no longer identical across presets.
  presets = let
    hd = x: (x + 1) / 2;             # ×½
    td = x: (2 * x + 3) / 6;         # ×⅓ → nearest int
    fscale = { num, den }: base: (base * num + den / 2) / den; # ≈ ×num/den, round-half-up
    f1080  = fscale { num = 11; den = 18; };                   # ghostty 18 → 11
    f720   = fscale { num = 10; den = 18; };                   # ghostty 18 → 10
    mk = f: {
      factor     = f.factor;                       # shown in the switch toast
      mode       = f.mode;                         # sway output mode; "native" = reload restores EDID
      gtkScale   = f.gtkScale;                     # GDK_SCALE popup launchers use (integers only: 2 → 1 → 1)
      accel      = f.accel;                        # pointer_accel (pointer + touchpad share it)
      titlebar   = f.titlebar;                     # sway titlebar_padding
      cursorSeat = f.cursorSeat;                   # sway seat cursor + gsettings cursor-size (+ gtk-3.0/settings.ini)
      fonts = {
        sway    = f.fonts.sway;                    # window titlebars
        waybar  = f.fonts.waybar;                  # bar labels
        mako    = f.fonts.mako;                    # notifications
        ghostty = f.fonts.ghostty;                 # terminal
        gtk     = f.fonts.gtk;                     # dconf font-name (GTK dialogs etc.)
        osd     = f.fonts.osd;                     # swayosd label (style.css literal 40px)
      };
      bar = {
        height       = f.bar.height;               # waybar config.jsonc literal 44
        iconSize     = f.bar.iconSize;             # tray icon
        spacing      = f.bar.spacing;              # tray spacing
        fontMinWidth = f.bar.fontMinWidth;         # workspace pill min-width
      };
      mako = {
        margin  = f.mako.margin;                   # mako config literals
        padding = f.mako.padding;
        border  = f.mako.border;
      };
      osd = {                                     # swayosd style.css literals (all ×display.osd)
        minWidth = f.osd.minWidth;                # 500px
        margin   = f.osd.margin;                  # 64px
        icon     = f.osd.icon;                    # 64px
        bar      = f.osd.bar;                     # 24px progressbar min-height
        seg      = f.osd.seg;                     # 32px segment margin-left
      };
      pavu    = { x = f.pavu.x;     y = f.pavu.y; };                              # popup anchors (4K → scaled)
      blueman = { w = f.blueman.w;  h = f.blueman.h;                              # blueman window size + anchor
                  x = f.blueman.x;  y = f.blueman.y; };
    };
  in {
    "720" = mk {
      factor = "1/3"; mode = "mode --custom 1280x720 scale 1"; gtkScale = td 2; accel = "0.2";
      titlebar = td titlebarPadding; cursorSeat = td display.cursor.seat;
      fonts = { sway = f720 font.points.sway; waybar = f720 font.points.waybar;
                mako = f720 font.points.mako; ghostty = f720 font.points.ghostty;
                gtk = f720 18; osd = f720 40; };
      bar = { height = td 44; iconSize = td bar.iconSize; spacing = td bar.spacing;
              fontMinWidth = td bar.fontMinWidth; };
      mako = { margin = td makoMargin; padding = td makoPadding; border = td makoBorder; };
      osd = { minWidth = td 500; margin = td 64; icon = td 64; bar = td 24; seg = td 32; };
      pavu = { x = td popups.pavucontrol.x; y = td popups.pavucontrol.y; };
      blueman = { w = td popups.blueman.w; h = td popups.blueman.h;
                  x = td popups.blueman.x; y = td popups.blueman.y; };
    };
    "1080" = mk {
      factor = "1/2"; mode = "mode --custom 1920x1080 scale 1"; gtkScale = hd 2; accel = "0.3";
      titlebar = hd titlebarPadding; cursorSeat = hd display.cursor.seat;
      fonts = { sway = f1080 font.points.sway; waybar = f1080 font.points.waybar;
                mako = f1080 font.points.mako; ghostty = f1080 font.points.ghostty;
                gtk = f1080 18; osd = f1080 40; };
      bar = { height = hd 44; iconSize = hd bar.iconSize; spacing = hd bar.spacing;
              fontMinWidth = hd bar.fontMinWidth; };
      mako = { margin = hd makoMargin; padding = hd makoPadding; border = hd makoBorder; };
      osd = { minWidth = hd 500; margin = hd 64; icon = hd 64; bar = hd 24; seg = hd 32; };
      pavu = { x = hd popups.pavucontrol.x; y = hd popups.pavucontrol.y; };
      blueman = { w = hd popups.blueman.w; h = hd popups.blueman.h;
                  x = hd popups.blueman.x; y = hd popups.blueman.y; };
    };
    "4k" = mk {
      factor = "1"; mode = "native"; gtkScale = 2; accel = "0.6";
      titlebar = titlebarPadding; cursorSeat = display.cursor.seat;
      fonts = { sway = font.points.sway; waybar = font.points.waybar;
                mako = font.points.mako; ghostty = font.points.ghostty;
                gtk = 18; osd = 40; };
      bar = { height = 44; iconSize = bar.iconSize; spacing = bar.spacing;
              fontMinWidth = bar.fontMinWidth; };
      mako = { margin = makoMargin; padding = makoPadding; border = makoBorder; };
      osd = { minWidth = 500; margin = 64; icon = 64; bar = 24; seg = 32; };
      pavu = { x = popups.pavucontrol.x; y = popups.pavucontrol.y; };
      blueman = { w = popups.blueman.w; h = popups.blueman.h;
                  x = popups.blueman.x; y = popups.blueman.y; };
    };
  };
}