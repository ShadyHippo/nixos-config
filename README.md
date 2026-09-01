# hippo-xps — NixOS configuration

A complete, reproducible desktop: **sway (Wayland) + zsh**, gruvbox-themed with a
hot-pink accent, built for an XPS 15 9570 (4K panel, Intel GPU rendering, 1050 Ti
disabled).

![desktop](images/desktop-screenshot-1.png)

## What's in here

- **Sway** — tiling WM, vim-direction focus, custom keybinding digests (`$mod+F1`)
- **Waybar / mako / fuzzel / swayosd / kanshi** — bar, notifications, launcher,
  OSD, per-monitor layout
- **zsh** — bare prompt (hot-pink `❯`), fzf-tab fuzzy Tab, lazy fzf `Ctrl+R`
  history, no prompt framework
- **GTK/Qt theming** — kvantum Qt + gruvbox GTK, recolored **hot-pink cursor**
  shared by session and greeter, regreet login
- **Apps** — Ghostty, VS Code/Neovim, qalculate, Dolphin (NAS/SMB), Zen browser,
  pavucontrol/blueman popups, Steam + Proton GE, Dolphin emulator + **joycond**
  (combined Joy-Cons), fcitx5 pinyin IME
- **Hardware** — keyd caps→escape, TLP power, Intel Wi-Fi/BT firmware,
  `hid_nintendo` driver, iGPU-only rendering

## The point of this repo: make it *yours* in two files

This config was designed so a different machine gets a fresh look **without
hunting through files**. Two files are the entire surface:

| File | What it controls |
|---|---|
| **`modules/theming.nix`** | every color (full Gruvbox palette + the hot-pink accent), GTK/Qt theme names, cursor theme, wallpaper |
| **`modules/sizing.nix`** | **one big file for ALL sizing**: fonts (sway/waybar/mako/ghostty), display scales (global Qt, per-app GTK), cursor sizes, floating popup anchors (pavucontrol/blueman), bar sizes |

Sway, Waybar, Mako, Ghostty and the per-app GTK/Qt env all read from those two
files — change a number, rebuild, done.

Per-monitor placement is the one thing NOT in `sizing.nix`: that's
`home/kanshi/config` (it maps outputs to *your* desks, not a global scale).

## Reproducing on your own hardware

1. Clone and enter the repo.
2. **Generate your hardware config**: `sudo nixos-generate-config --root /` and
   copy the resulting `hardware-configuration.nix` over the one here (mine is
   XPS-9570-specific).
3. **Look the part**: edit `modules/theming.nix` and `modules/sizing.nix`
   (screen size → scales; taste → colors). Adjust `home/kanshi/config`.
4. **You**: if your username isn't `hippo`, update `users.users.hippo` in
   `modules/base.nix` and `home.username` in `home/default.nix`.
5. Build: `sudo nixos-rebuild switch --flake .#hippo-xps`

## Layout

```
flake.nix               # entry: nixpkgs pins, system, home-manager
configuration.nix       # machine-level glue (env vars via theming/sizing)
modules/
  base.nix              # system packages, users, ssh, basics
  hardware.nix          # XPS-specific: kernel modules, firmware, TLP, BT
  theming.nix           # ← ALL colors/theme choices (pure data)
  sizing.nix            # ← ONE BIG FILE: all fonts/scales/anchors (pure data)
  desktop.nix           # sway/regreet/GTK+Qt theming plumbing
  apps.nix dev.nix audio.nix gaming.nix
home/
  default.nix           # home-manager: shells, scripts, dotfiles wiring
  sway/ waybar/ mako/ ghostty/ fuzzel/ kanshi/ swayosd/ cursor/ kvantum/
```

## Public-repo hygiene

- No secrets in the tree: only a commented-out example proxy line.
- `cont_maki.sh` (a maki session helper) is gitignored; it existed in early
  commits, so if you want it gone from *history* too, purge with
  `git filter-repo` (rewrites SHAs — one-time, then force-push).
- Screenshots live in `images/` — replace `desktop-screenshot-1.png` to taste.

## Roadmap-ish (deliberately small)

- `home/swayosd/style.css` still holds its px values literally (follows
  `sizing.nix`'s `display.osd` — bump them together); converting it to a fully
  generated file is optional.
- Neovim + VS Code ship stock configs; a real nvim setup is future work.