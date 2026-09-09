# GTK4 gruvbox theme for non-libadwaita apps (pavucontrol).
# gruvbox-dark ships no gtk-4.0 theme, so GTK_THEME falls back to light —
# this provides one explicitly. Follows machine/theme.nix palette changes.
theme:

let
  pal = theme.palette;
in ''
  /* Gruvbox-dark GTK4 theme (non-libadwaita apps, e.g. pavucontrol). Matches
     the gruvbox look blueman (GTK3) gets from gtk-3.0/settings.ini. */
  window, window.background, .background, .view {
    background-color: ${pal.bg};
    color: ${pal.fg};
  }
  box, grid, .content, stack, list, listview, .list, .rich-list {
    background-color: ${pal.bg};
    color: ${pal.fg};
  }
  headerbar, .titlebar {
    background-color: ${pal.bgAlt};
    color: ${pal.fg};
    border-bottom: 1px solid ${pal.bgDim};
  }
  label { color: ${pal.fg}; }
  .dim-label, label.dim { color: ${pal.fgDim}; }
  button {
    background-color: ${pal.bgAlt};
    border-color: ${pal.bgDim};
    color: ${pal.fg};
    border-radius: 4px;
  }
  button:hover { background-color: ${pal.bgDim}; }
  button:active, button:checked { background-color: ${pal.bgDim}; }
  button.flat { background: transparent; }
  /* pavucontrol tabstrip: GtkStackSwitcher (underline style); notebook fallback */
  .stack-switcher { background-color: ${pal.bgAlt}; padding: 0 8px; }
  .stack-switcher > button {
    background: transparent;
    color: ${pal.fgDim};
    border: none;
    box-shadow: none;
    padding: 8px 20px;
    margin: 0 2px;
  }
  .stack-switcher > button:hover { background-color: ${pal.bgDim}; }
  .stack-switcher > button:checked {
    background-color: ${pal.bg};
    color: ${pal.fg};
    box-shadow: inset 0 -2px 0 ${pal.blue};
  }
  notebook, .notebook { background-color: ${pal.bg}; }
  notebook > header { background-color: ${pal.bgAlt}; }
  notebook > header > tabs > tab {
    background-color: ${pal.bgAlt};
    color: ${pal.fgDim};
    border-bottom: 2px solid transparent;
    padding: 8px 20px;
    margin: 0 2px;
  }
  notebook > header > tabs > tab:checked {
    background-color: ${pal.bg};
    color: ${pal.fg};
    border-bottom: 2px solid ${pal.blue};
  }
  scale trough { background-color: ${pal.bgDim}; min-height: 8px; border-radius: 4px; }
  scale highlight { background-color: ${pal.blue}; border-radius: 4px; }
  scale slider { background-color: ${pal.fg}; border: 2px solid ${pal.bgDim}; border-radius: 50%; }
  entry, spinbutton {
    background-color: ${pal.bgAlt};
    border-color: ${pal.bgDim};
    color: ${pal.fg};
    caret-color: ${pal.fg};
  }
  entry:focus { border-color: ${pal.blue}; }
  combobox button, combobox { background-color: ${pal.bgAlt}; color: ${pal.fg}; border-color: ${pal.bgDim}; }
  popover, menu, .menu, .popover, dropdown, combobox > window.popover {
    background-color: ${pal.bgAlt};
    color: ${pal.fg};
    border: 1px solid ${pal.bgDim};
  }
  modelbutton { background-color: ${pal.bgAlt}; color: ${pal.fg}; }
  modelbutton:hover { background-color: ${pal.bgDim}; }
  textview, textview text { background-color: ${pal.bg}; color: ${pal.fg}; }
  separator { background-color: ${pal.bgDim}; }
  frame, frame > border { border: 1px solid ${pal.bgDim}; }
  row { background-color: ${pal.bg}; color: ${pal.fg}; }
  row:hover { background-color: ${pal.bgAlt}; }
  scrollbar { background-color: ${pal.bgAlt}; }
  scrollbar slider { background-color: ${pal.bgDim}; }
  check, radio { background-color: ${pal.bgAlt}; color: ${pal.fg}; }
  check:checked, radio:checked { background-color: ${pal.blue}; }
  switch { background-color: ${pal.bgDim}; }
  switch:checked { background-color: ${pal.blue}; }
  progressbar trough { background-color: ${pal.bgDim}; }
  progressbar progress { background-color: ${pal.blue}; }
  tooltip, .osd { background-color: ${pal.bgAlt}; color: ${pal.fg}; border: 1px solid ${pal.bgDim}; }
''
