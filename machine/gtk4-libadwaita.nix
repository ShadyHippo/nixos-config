# libadwaita color overrides for GTK4 libadwaita apps (Kooha, GNOME apps).
#
# Why this exists: libadwaita apps paint from libadwaita's OWN stylesheet and
# ignore GTK_THEME / theme CSS entirely (unlike pavucontrol, see
# gtk4-theme.nix). The only supported override is the USER stylesheet
# ~/.config/gtk-4.0/gtk.css — it loads at GTK_STYLE_PROVIDER_PRIORITY_USER,
# which outranks the APPLICATION-priority provider libadwaita installs.
# libadwaita 1.4+ reads these as CSS custom properties (`--window-bg-color` …),
# NOT the legacy @define-color names. Follows machine/theme.nix palette.
theme:

let
  pal = theme.palette;
in ''
  /* Gruvbox-dark for libadwaita apps. Only variables libadwaita consumes are
     set; the standalone --*-color variants are auto-derived from the matching
     --*-bg-color, so they are intentionally left alone. Non-libadwaita GTK4
     apps simply never read these. */
  :root {
    /* window / view */
    --window-bg-color: ${pal.bg};
    --window-fg-color: ${pal.fg};
    --view-bg-color: ${pal.bg};
    --view-fg-color: ${pal.fg};

    /* header bars / toolbars */
    --headerbar-bg-color: ${pal.bgAlt};
    --headerbar-fg-color: ${pal.fg};
    --headerbar-border-color: ${pal.bgDim};
    --headerbar-backdrop-color: ${pal.bg};
    --headerbar-shade-color: rgb(0 0 0 / 36%);
    --headerbar-darker-shade-color: rgb(0 0 0 / 90%);

    /* sidebars */
    --sidebar-bg-color: ${pal.bgAlt};
    --sidebar-fg-color: ${pal.fg};
    --sidebar-backdrop-color: ${pal.bg};
    --sidebar-border-color: ${pal.bgDim};
    --sidebar-shade-color: rgb(0 0 0 / 25%);
    --secondary-sidebar-bg-color: ${pal.bgAlt};
    --secondary-sidebar-fg-color: ${pal.fg};
    --secondary-sidebar-backdrop-color: ${pal.bg};
    --secondary-sidebar-border-color: ${pal.bgDim};
    --secondary-sidebar-shade-color: rgb(0 0 0 / 25%);

    /* cards / boxed lists */
    --card-bg-color: ${pal.bgAlt};
    --card-fg-color: ${pal.fg};
    --card-shade-color: rgb(0 0 0 / 36%);

    /* popovers / dialogs */
    --popover-bg-color: ${pal.bgAlt};
    --popover-fg-color: ${pal.fg};
    --popover-shade-color: rgb(0 0 0 / 25%);
    --dialog-bg-color: ${pal.bgAlt};
    --dialog-fg-color: ${pal.fg};

    /* tab overview / thumbnails / toggle groups */
    --overview-bg-color: ${pal.bg};
    --overview-fg-color: ${pal.fg};
    --thumbnail-bg-color: ${pal.bgAlt};
    --thumbnail-fg-color: ${pal.fg};
    --active-toggle-bg-color: ${pal.bgAlt};
    --active-toggle-fg-color: ${pal.fg};

    /* accent (interactive / selected): gruvbox blue with dark text */
    --accent-bg-color: ${pal.blue};
    --accent-fg-color: ${pal.bg};

    /* status */
    --destructive-bg-color: ${pal.red};
    --destructive-fg-color: ${pal.fg};
    --success-bg-color: ${pal.green};
    --success-fg-color: ${pal.bg};
    --warning-bg-color: ${pal.yellow};
    --warning-fg-color: ${pal.bg};
    --error-bg-color: ${pal.red};
    --error-fg-color: ${pal.fg};

    /* misc */
    --shade-color: rgb(0 0 0 / 25%);
    --scrollbar-outline-color: rgb(0 0 0 / 50%);
  }
''
