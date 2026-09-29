# Waybar — bar config (token-substituted template) + generated CSS.
# The @TOKEN@ approach in the JSONC is deliberate: generating the entire config
# in Nix would lose the inline comments. Substitution goes through
# lib/tokens.nix, which FAILS EVALUATION if a token is left unreplaced.
{ ... }:

let
  theme = import ../machine/theme.nix;
  pal   = theme.palette;
  tokens = import ../lib/tokens.nix;
in
{
  # force: set-res.sh rewrites at runtime; must not back up.
  xdg.configFile."waybar/config.jsonc" = {
    force = true;
    text = tokens "waybar/config.jsonc" {
      BAR_ICON_SIZE = toString theme.bar.iconSize;
      BAR_SPACING   = toString theme.bar.spacing;
    } (builtins.readFile ./waybar/config.jsonc);
  };

  xdg.configFile."waybar/style.css" = {
    force = true;
    text = ''
      /* waybar — gruvbox, generated from machine/theme.nix */
      * {
          border: none;
          border-radius: 0;
          font-family: "${theme.font.family}", sans-serif;
          font-size: ${toString theme.font.points.waybar}px;
          min-height: 0;
      }

      window#waybar {
          background: ${pal.bg};
          color: ${pal.fg};
      }

      #workspaces button {
          padding: 0 6px;
          min-width: ${toString theme.bar.fontMinWidth}px;
          background: transparent;
          color: ${pal.fgDim};
      }

      #workspaces button.focused {
          background: ${pal.blue};
          color: ${pal.bg};
      }

      #workspaces button.urgent {
          background: ${pal.red};
          color: ${pal.fg};
      }

      #window {
          font-style: italic;
      }

      #clock,
      #battery,
      #bluetooth,
      #memory,
      #custom-disk,
      #temperature,
      #pulseaudio,
      #tray {
          padding: 0 8px;
          background: transparent;
      }

      #memory.warning,
      #custom-disk.warning,
      #temperature.warning {
          color: ${pal.yellow};
      }

      #memory.critical,
      #custom-disk.critical {
          color: #fb4934;
      }

      #battery.warning {
          color: ${pal.yellow};
      }

      #battery.critical:not(.charging) {
          color: #fb4934;
          animation: blink 1s linear infinite alternate;
      }

      #temperature.critical {
          color: #fb4934;
      }

      #bluetooth.connected {
          color: ${pal.accent};
      }

      #bluetooth.off,
      #bluetooth.disabled {
          color: ${pal.gray};
      }

      @keyframes blink {
          to {
              background: ${pal.red};
              color: ${pal.bg};
          }
      }
    '';
  };
}
