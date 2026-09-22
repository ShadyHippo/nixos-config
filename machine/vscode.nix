# ─────────────────────────────────────────────────────────────────────────────
# VS CODE — my editor config.
#
# Not a common need — this whole file is one trimmable unit. To remove:
#   1. delete this file
#   2. remove `./machine/vscode.nix` from flake.nix's modules list
#
# Everything VS Code touches lives here: the package, extensions and settings.
# Removing this file (and its import in flake.nix) drops VS Code entirely —
# there is no separate home.packages entry for it.
# ─────────────────────────────────────────────────────────────────────────────
{ pkgs, ... }:

let
  identity = import ./identity.nix;
in
{
  home-manager.users.${identity.username} = {
    programs.vscode = {
      enable = true;
      profiles.default.extensions = with pkgs.vscode-extensions; [
        golang.go
        jdinhlife.gruvbox
        jnoortheen.nix-ide
        mechatroner.rainbow-csv
        oderwat.indent-rainbow
        vscodevim.vim
        llvm-vs-code-extensions.vscode-clangd
        dbaeumer.vscode-eslint
        esbenp.prettier-vscode
        mkhl.direnv
      ];
      profiles.default.userSettings = {
        "workbench.sideBar.location" = "right";
        "window.zoomLevel" = 2.5;
        "files.autoSave" = "afterDelay";
        "editor.formatOnSave" = true;
        "workbench.colorTheme" = "Gruvbox Dark Hard";
        "vim.useSystemClipboard" = true;
        "vim.hlsearch" = true;
        "vim.visualstar" = true;
        "vim.handleKeys" = {
          "<C-p>" = false;
        };
        "editor.lineNumbers" = "relative";
        "search.showLineNumbers" = true;
        "explorer.confirmDragAndDrop" = false;
        "explorer.confirmDelete" = false;
        "workbench.colorCustomizations" = {
          "editorBracketHighlight.foreground1" = "#003ad8";
          "editorBracketHighlight.foreground2" = "#c58700";
          "editorBracketHighlight.foreground3" = "#ea00ff";
          "editorBracketHighlight.foreground4" = "#0bbe89";
          "editorBracketHighlight.foreground5" = "#fffb00";
          "editorBracketHighlight.foreground6" = "#21c700";
          "editorBracketHighlight.unexpectedBracket.foreground" = "#ff0000";
        };
      };
      profiles.default.keybindings = [
        {
          key = "ctrl+shift+s";
          command = "workbench.action.files.saveAll";
        }
        {
          key = "alt+shift+f";
          command = "editor.action.formatDocument";
          when = "editorTextFocus && !editorReadonly";
        }
      ];
    };

    # VS Code icon: package ships 1024x1024 but launcher shows a blank box;
    # pin into user icon theme so it resolves.
    home.file.".local/share/icons/hicolor/128x128/apps/vscode.png".source =
      "${pkgs.vscode}/share/icons/hicolor/1024x1024/apps/vscode.png";
  };
}