# Shell + dev tooling: zsh/fzf/mise/git/gh and the Ghostty terminal config.
{ pkgs, unstable, ... }:

let
  theme = import ../machine/theme.nix;
  pal   = theme.palette;
in
{
  # Ghostty terminal — config written directly (no HM module: that adds a
  # systemd single-instance daemon + shell integration we don't want).
  # Values from theme.nix. force: set-res.sh rewrites font-size at runtime.
  home.file.".config/ghostty/config" = {
    force = true;
    text = ''
      theme = "Gruvbox Dark"
      font-family = ${theme.font.family}
      font-size = ${toString theme.font.points.ghostty}
      copy-on-select = clipboard
    '';
  };

  # fastfetch: no config override, uses defaults (auto-detects NixOS logo).

  # bash: zsh is the login shell; this only keeps interactive bash working
  # (HM writes ~/.bashrc so session variables are sourced there too).
  programs.bash.enable = true;

  # ---------------------------------------------------------------------------
  # Shell: zsh — fzf-tab fuzzy completion on <Tab>, fzf history on <Ctrl+R>
  # ---------------------------------------------------------------------------
  programs.zsh = {
    enable = true;
    shellAliases = {
      sa2-mods = "$HOME/nixos-config/SA2 Modding/launch-manager.sh";
      sa2-setup = "$HOME/nixos-config/SA2 Modding/setup-sa2b.sh";
    };
    enableCompletion = true;
    history = {
      path = "$HOME/.config/zsh/.zsh_history";
      size = 50000;
      save = 50000;
      ignoreDups = true;
      ignoreAllDups = true;
      ignoreSpace = true;
      findNoDups = true;
      share = true;
    };
    plugins = [
      {
        name = "fzf-tab";
        src = pkgs.zsh-fzf-tab;
        file = "share/fzf-tab/fzf-tab.zsh";
      }
    ];
    initContent = ''
  # fzf-tab: <Tab> opens a fuzzy finder for the current directory
      zstyle ':completion:*' menu no
      zstyle ':fzf-tab:*' switch-group '<' '>'

      # Preview the directory when tab-completing cd / paths
      zstyle ':fzf-tab:complete:cd:*' fzf-preview \
        'ls -1 --color=always $realpath 2>/dev/null || echo $realpath'
      zstyle ':fzf-tab:complete:cd:*' fzf-flags '--height=40%' '--layout=reverse' '--border'

      # Kill completion: preview the command behind the PID being completed
      zstyle ':fzf-tab:complete:kill:argument-*' fzf-preview \
        'ps --pid=$word -o comm --no-headers 2>/dev/null || true'

      # ---- lazy Ctrl+R: fuzzy history search ----
      if [[ -o zle ]]; then
        _fzf_history() {
          local sel
          sel=$(fc -ln 1 | fzf --height=40% --layout=reverse --border --query="$BUFFER")
          if [[ -n "$sel" ]]; then
            BUFFER="$sel"
            CURSOR=$#BUFFER
          fi
          zle reset-prompt
        }
        zle -N _fzf_history
        bindkey '^R' _fzf_history
      fi

      # ---- bare prompt: ~/path ❯ (hot-pink), red ❯ on error ----
      PROMPT='%B%F{${pal.accent}}%~%f %(!.%F{#fb4934}#.%(?.%F{${pal.accent}}.%F{#fb4934})❯)%f%b '
    '';
  };

  # fzf: installs the binary (fzf-tab needs it); zsh integration disabled —
  # Ctrl+R is a lazy widget that spawns fzf only when pressed.
  programs.fzf = {
    enable = true;
    enableZshIntegration = false;
  };

  programs.mise = {
    enable = true;
    package = unstable.mise;
  };

  xdg.configFile."mise/config.toml".text = ''
    [tools]
    opencode = "latest"
    "github:tontinton/maki" = "latest"
    "github:yt-dlp/yt-dlp" = { version = "latest", github_attestations = false }
    deno = "latest"
    golang = "latest"
    "github:ptcodes/BatteryScope" = "latest"
  '';

  programs.gh.enable = true;

  programs.git = {
    enable = true;
    settings = {
      user.name = "ShadyHippo";
      user.email = "tim.vandyke123@gmail.com";
      push.autoSetupRemote = true;
    };
  };

  # VSCode config lives in machine/vscode.nix (trimmable user favorite).
}
