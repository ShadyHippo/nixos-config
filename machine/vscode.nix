# ─────────────────────────────────────────────────────────────────────────────
# VS CODE — my editor config.
#
# Not a common need — this whole file is one trimmable unit. To remove:
#   1. delete this file
#   2. remove `./machine/vscode.nix` from flake.nix's modules list
#
# Nix manages only the package and the extension set. settings.json and
# keybindings.json are deliberately NOT managed — VS Code owns them, so edits
# in-app persist and need no rebuild. The extensions dir is mutable
# (home-manager's default for a default-only profile set), so installs made in
# the UI coexist with the ones declared below.
#
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
        ms-vscode-remote.remote-ssh
        ms-vscode-remote.remote-ssh-edit
        jnoortheen.nix-ide
        mechatroner.rainbow-csv
        oderwat.indent-rainbow
        vscodevim.vim
        llvm-vs-code-extensions.vscode-clangd
        dbaeumer.vscode-eslint
        esbenp.prettier-vscode
        mkhl.direnv
      ];
    };

    # VS Code icon: package ships 1024x1024 but launcher shows a blank box;
    # pin into user icon theme so it resolves.
    home.file.".local/share/icons/hicolor/128x128/apps/vscode.png".source =
      "${pkgs.vscode}/share/icons/hicolor/1024x1024/apps/vscode.png";
  };
}
