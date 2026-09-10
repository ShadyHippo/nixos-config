# ─────────────────────────────────────────────────────────────────────────────
# RESOLUTION — runtime resolution presets ($mod+F10/11/12 → 720p/1080p/4K).
#
# MACHINE-SPECIFIC: tied to the Sharp 4K panel's fixed-function scaler and the
# iGPU's modeset limitations. Delete this file, machine/set-res.sh, and the
# import in home/default.nix when moving to different hardware.
#
# The panel exposes only ONE EDID mode (3840×2160); sub-4K modes composite on
# the iGPU and the fixed scaler upscales to native. Every framebuffer px is 2
# (1080p) or 3 (720p) physical px. Dimensions are halved/thirded to stay
# physically identical; fonts use user-tuned ratios (not geometric).
#
# All numbers are derived from machine/theme.nix at config time — edit
# theme.nix, rebuild, then re-press the preset key. This script edits the
# INSTALLED configs, so a later `home-manager switch` regenerates them to 4K
# base values (re-press a preset key to re-apply).
# ─────────────────────────────────────────────────────────────────────────────
theme:

let
  inherit (theme) font display popups bar titlebarPadding makoMargin makoPadding makoBorder;

  # ── PRESET MATH ──
  hd = x: (x + 1) / 2;             # ×½
  td = x: (2 * x + 3) / 6;         # ×⅓ → nearest int
  fscale = { num, den }: base: (base * num + den / 2) / den; # ≈ ×num/den, round-half-up
  f1080  = fscale { num = 11; den = 18; };                   # ghostty 18 → 11
  f720   = fscale { num = 10; den = 18; };                   # ghostty 18 → 10

  mk = f: {
    factor     = f.factor;
    mode       = f.mode;
    gtkScale   = f.gtkScale;
    accel      = f.accel;
    titlebar   = f.titlebar;
    cursorSeat = f.cursorSeat;
    fonts = {
      sway    = f.fonts.sway;
      waybar  = f.fonts.waybar;
      mako    = f.fonts.mako;
      ghostty = f.fonts.ghostty;
      gtk     = f.fonts.gtk;
      osd     = f.fonts.osd;
    };
    bar = {
      height       = f.bar.height;
      iconSize     = f.bar.iconSize;
      spacing      = f.bar.spacing;
      fontMinWidth = f.bar.fontMinWidth;
    };
    mako = {
      margin  = f.mako.margin;
      padding = f.mako.padding;
      border  = f.mako.border;
    };
    osd = {
      minWidth = f.osd.minWidth;
      margin   = f.osd.margin;
      icon     = f.osd.icon;
      bar      = f.osd.bar;
      seg      = f.osd.seg;
    };
    pavu    = { x = f.pavu.x;     y = f.pavu.y; };
    bluejay = { w = f.bluejay.w; h = f.bluejay.h; x = f.bluejay.x; y = f.bluejay.y; };
  };

  presets = {
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
      bluejay = { w = td popups.bluejay.w; h = td popups.bluejay.h;
                  x = td popups.bluejay.x; y = td popups.bluejay.y; };
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
      bluejay = { w = hd popups.bluejay.w; h = hd popups.bluejay.h;
                  x = hd popups.bluejay.x; y = hd popups.bluejay.y; };
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
      bluejay = { w = popups.bluejay.w; h = popups.bluejay.h;
                  x = popups.bluejay.x; y = popups.bluejay.y; };
    };
  };

  # ── SED PATTERN GENERATION ──
  mkSway = p: builtins.concatStringsSep "\n" (
      [ ( "/^output eDP-1 mode/d"
          + (if p.mode == "native" then "" else "\n$a output eDP-1 ${p.mode}") )
        "s|^font .*\\b[0-9]\\+$|font ${font.family} ${toString p.fonts.sway}|"
        "s|^seat \\* xcursor_theme .*\\b[0-9]\\+$|seat * xcursor_theme ${theme.cursorTheme} ${toString p.cursorSeat}|"
        "s|pointer_accel .*|pointer_accel ${p.accel}|"
        "s|^titlebar_padding .*|titlebar_padding ${toString p.titlebar}|"
        "s|\\(for_window \\[[a-z_]*=\"(?i)pavucontrol\"\\]\\) move position [0-9 ]*|\\1 move position ${toString p.pavu.x} ${toString p.pavu.y}|g"
        "s|\\(for_window \\[[a-z_]*=\"(?i)io.github.ebonjaeger.bluejay\"\\]\\) resize set [0-9 x]*|\\1 resize set ${toString p.bluejay.w} ${toString p.bluejay.h}|g"
        "s|\\(for_window \\[[a-z_]*=\"(?i)io.github.ebonjaeger.bluejay\"\\]\\) move position [0-9 ]*|\\1 move position ${toString p.bluejay.x} ${toString p.bluejay.y}|g"
      ] );
  mkWaybar = p: builtins.concatStringsSep "\n" [
    "s|font-size: [0-9]*px;|font-size: ${toString p.fonts.waybar}px;|"
    "s|min-width: [0-9]*px;|min-width: ${toString p.bar.fontMinWidth}px;|"
    "s|\"height\": [0-9]*|\"height\": ${toString p.bar.height}|"
    "s|\"icon-size\": [0-9]*|\"icon-size\": ${toString p.bar.iconSize}|"
    "s|\"spacing\": [0-9]*|\"spacing\": ${toString p.bar.spacing}|"
  ];
  mkMako = p: builtins.concatStringsSep "\n" [
    "s|^font=.*|font=${font.family} ${toString p.fonts.mako}|"
    "s|^margin=[0-9]*|margin=${toString p.mako.margin}|"
    "s|^padding=[0-9]*|padding=${toString p.mako.padding}|"
    "s|^border-size=[0-9]*|border-size=${toString p.mako.border}|"
  ];
  mkGhost = p: "s|^font-size = [0-9.]*|font-size = ${toString p.fonts.ghostty}|";
  mkOsd = p: builtins.concatStringsSep "\n" [
    "s|min-width: [0-9]*px;|min-width: ${toString p.osd.minWidth}px;|"
    "s|margin: [0-9]*px;|margin: ${toString p.osd.margin}px;|"
    "s|font-size: [0-9]*px;|font-size: ${toString p.fonts.osd}px;|"
    "s|-gtk-icon-size: [0-9]*px;|-gtk-icon-size: ${toString p.osd.icon}px;|"
    "s|min-height: [0-9]*px;|min-height: ${toString p.osd.bar}px;|"
    "s|margin-left: [0-9]*px;|margin-left: ${toString p.osd.seg}px;|"
  ];
  mkGtkIni = p: "s|gtk-cursor-theme-size=.*|gtk-cursor-theme-size=${toString p.cursorSeat}|";
  # sed patterns go inside bash double-quoted assignments, so quotes AND dollar
  # signs must be escaped first ($a → the sed append command would otherwise
  # be expanded by bash as the empty variable $a):
  esc = s: builtins.replaceStrings [ "\"" "$" ] [ "\\\"" "\\$" ] s;
  tok = k: p: {
    o = [ "@FACTOR_${k}@" "@SCALE_${k}@" "@ACCEL_${k}@" "@GTK_FONT_${k}@" "@CURSOR_${k}@"
          "@SWAY_${k}@" "@WB_${k}@" "@MAKO_${k}@" "@GHOST_${k}@" "@OSD_${k}@" "@GTKINI_${k}@" ];
    n = [ p.factor (toString p.gtkScale) p.accel (toString p.fonts.gtk) (toString p.cursorSeat)
          (esc (mkSway p)) (esc (mkWaybar p)) (esc (mkMako p)) (esc (mkGhost p)) (esc (mkOsd p)) (esc (mkGtkIni p)) ];
  };
  all = map (k: tok k presets.${k}) [ "720" "1080" "4k" ];
in
# Returns the xdg.configFile attrset to install the generated script.
{
  xdg.configFile."sway/scripts/set-res.sh" = {
    executable = true;
    text = builtins.replaceStrings
      (builtins.concatLists (map (x: x.o) all))
      (builtins.concatLists (map (x: x.n) all))
      (builtins.readFile ./set-res.sh);
  };
}
