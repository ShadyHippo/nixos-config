# ─────────────────────────────────────────────────────────────────────────────
# THEMING — every color / theme decision in one place.
#
# New machine? Want a different look? Edit THIS file, then rebuild. Sway,
# waybar, mako, the recolored cursor and GTK/Qt env all follow automatically.
#
# NOTE: this file is pure data. It is imported by configuration.nix and the
# modules/*.nix + home/default.nix — nothing here sets NixOS options by itself.
# ─────────────────────────────────────────────────────────────────────────────
{
  # ── Gruvbox palette + the hot-pink signature accent ──
  # Hexes only; every consumer (sway, waybar, mako, cursors) is templated from
  # these, so changing one value re-themes the whole desktop.
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
  # The mouse cursor uses palette.accent (body) + palette.green (outline).
  cursorTheme = "Bibata-Modern-Classic";

  # ── Wallpaper (absolute path; file lives in home-manager) ──
  wallpaper = "/home/hippo/.local/share/backgrounds/gruvbox-astronaut-4k.png";
}