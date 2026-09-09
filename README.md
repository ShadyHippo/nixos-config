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
- **Apps** — Ghostty, Neovim, qalculate, Dolphin (NAS/SMB), Zen browser,
  pavucontrol/blueman popups, Steam + Proton GE, **joycond**
  (combined Joy-Cons), fcitx5 pinyin IME (see `machine/fcitx5.nix`), VS Code
  (see `machine/vscode.nix`)
- **Emulation** — **RetroDECK flatpak** (`net.retrodeck.retrodeck`) manages all
  emulators (Dolphin, RetroArch, PCSX2, etc.) and their configs. ROMs, BIOS,
  saves, and texture packs live in `~/retrodeck/`. RetroDECK has a built-in
  Backup tool (Configurator → Data Management Tools) for portability.
- **Hardware** — keyd caps→escape, thermald + undervolt, Intel Wi-Fi/BT
  firmware, `hid_nintendo` driver, iGPU-only rendering (1050 Ti disabled)

## Packaging: NixOS, mise, and flatpak — which goes where?

Three package managers live here, and the split is deliberate:

| Concern | System |
|---|---|
| **The desktop itself** — kernel, services, sway, theming, desktop + system packages | **NixOS** (`modules/*`, `configuration.nix`) — declared once, rebuilds atomically |
| **User-level dev tools you bump constantly** — `opencode`, `maki`, `yt-dlp`, `deno`, `golang` | **mise** (`home/default.nix` → `programs.mise`, tools in `mise/config.toml`) |
| **Emulators** — Dolphin, RetroArch, PCSX2, etc. with their own config/data layout | **RetroDECK flatpak** (`net.retrodeck.retrodeck`) — declared in `home/default.nix` via nix-flatpak |

The rule of thumb: **part of the environment → Nix; a tool in your toolbox
that you update weekly and version per project → mise; an app with its own
config universe that needs portability → flatpak.** Pinning bleeding-edge
CLIs in the Nix closure would slow every rebuild for zero gain — mise gives
per-tool/per-project versions without touching the system.

### RetroDECK (emulation)

RetroDECK is a single flatpak that wraps all emulators. Data lives in two places:

| Path | Contents | Portable? |
|---|---|---|
| `~/retrodeck/` | ROMs, BIOS, saves, texture packs, shaders, screenshots | **Yes** — copy to NAS, restore on new PC |
| `~/.var/app/net.retrodeck.retrodeck/config/` | Emulator configs (Dolphin, RetroArch, etc.) | Version-sensitive — use RetroDECK's built-in backup |

To transfer to a new PC: RetroDECK → Configurator → Data Management Tools →
Backup RetroDECK → save the `.tar` to NAS → install flatpak on new PC → restore.

## The `machine/` directory — make it *yours* in one place

Everything that is specific to **this computer / this user** lives in `machine/`.
The rest of the repo (`modules/`, `home/`, `configuration.nix`) is generic and
reusable. A new adopter touches almost nothing outside `machine/`.

Deleting a file + its one import line in `flake.nix` removes the feature
entirely — each file below is self-contained.

### File-by-file: what to change for a new machine

| File | What it holds | For a new user |
|---|---|---|
| **`machine/identity.nix`** | `username`, `hostname` | **Always change.** Drives the NixOS user, home-manager user, hostname, flake config name (`. #<hostname>`), and even the wallpaper path. Imported by flake.nix, configuration.nix, modules/, and home/. |
| **`machine/theme.nix`** | Palette (gruvbox + hot-pink accent), GTK/Qt theme names, cursor, wallpaper path, font family/sizes, display scales, popup anchors, bar size | **Edit for your taste/screen.** Colors → re-theme everything. `display.*` → rescale for your panel. Font sizes are tuned for 4K@scale 1. Consumed by configuration.nix, modules/desktop.nix, home/, and the generators below — edit it, everything follows. |
| **`machine/hardware.nix`** | XPS 9570-specific: NVIDIA disable + udev rule, thermald, Dell fan profile unit, undervolt (-160mV), keyd caps→esc | **Often delete outright** if you're not on an XPS 15 9570. Remove `./machine/hardware.nix` from flake.nix. Undervolt values are tuned for this chip — re-measure yours. keyd caps→esc is a preference you may keep. |
| **`machine/printing.nix`** | Brother MFC-J6555DW drivers (`brgenml1*`), brscan5 scan backend, avahi, scan/print GUIs | **Delete** if you don't have this printer (remove its flake.nix import). If you have a Brother, add your model's IP/nodename in `hardware.sane.brscan5.netDevices` (there's an example comment). |
| **`machine/fcitx5.nix`** | Simplified-Chinese Pinyin IME: system `i18n.inputMethod`, CJK font, user configs, sway autostart + `$mod+Shift+t` toggle | **Delete** if you don't need Chinese input (remove its flake.nix import). Nothing else depends on it. |
| **`machine/vscode.nix`** | VS Code: extensions, user settings, keybindings, icon fix | **Delete or edit** to your taste (remove its flake.nix import). The package installs via home-manager's `programs.vscode`, so removal is complete. |
| **`machine/resolution.nix`** + **`machine/set-res.sh`** | `$mod+F10/F11/F12` resolution presets (720p/1080p/4K) for the Sharp 4K panel — preset math + sed-generators + the script template | **Delete both** unless you have a panel with a fixed scaler like this one (remove the import in `home/default.nix`). If you keep it: values derive from `theme.nix`, nothing else to edit. |
| **`machine/gtk4-theme.nix`** | GTK4 gruvbox CSS for non-libadwaita apps (pavucontrol), generated from the palette | **Keep** — it only uses palette values; if you change the palette in `theme.nix` it follows automatically. If you must remove it, delete the import in `home/default.nix` and the `xdg.dataFile` entry that uses it. |

Sway, Waybar, Mako, Ghostty and the per-app GTK/Qt env all read from
`machine/theme.nix` — change a number, rebuild, done.

Per-monitor placement is NOT in `theme.nix`: that's
`home/kanshi/config` (it maps outputs to *your* desks, not a global scale).

> **A note for LLM adopters:** this config was deliberately written so that
> `machine/` is the ONLY directory you need to reason about to port it.
> Everything machine-specific + optional lives there. Two import sites matter:
> **flake.nix** imports `hardware.nix`, `printing.nix`, `fcitx5.nix`,
> `vscode.nix` (remove the line to drop the feature); **home/default.nix**
> imports `theme.nix`, `resolution.nix`, and `gtk4-theme.nix` (and reads
> `identity.nix`). Treat each file as an independent, removable unit — nothing
> outside `machine/` is machine-tuned. Beware of `machine/resolution.nix`: it
> looks like a module but is really a script generator with sed-pattern
> metaprogramming; delete it whole rather than editing it. `home/sway/config`
> is the static sway config; dynamic values (font, colors, popups) append via
> `extraConfig` from `theme.nix`.

## Reproducing on your own hardware

1. Clone and enter the repo.
2. **Generate your hardware config**: `sudo nixos-generate-config --root /` and
   copy the resulting `hardware-configuration.nix` over the one here (mine is
   XPS-9570-specific).
3. **You**: edit `machine/identity.nix` (username, hostname).
4. **Hardware**: delete `machine/hardware.nix` and `machine/printing.nix`
   (remove their imports in `flake.nix`), and `machine/resolution.nix` +
   `machine/set-res.sh` (remove the import in `home/default.nix`) if they
   don't apply — see the table above.
5. **Look the part**: edit `machine/theme.nix` (screen size → scales; taste →
   colors). Adjust `home/kanshi/config` for your monitors.
6. **Optional features**: delete `machine/fcitx5.nix` (IME) or
   `machine/vscode.nix` if you don't want them.
7. Build: `sudo nixos-rebuild switch --flake .#<hostname from machine/identity.nix>` \
   (for this machine: `.#hippo-xps`)

## Keybindings (`$mod` = Super/Windows key)

Sway is near-stock — everything not listed here keeps its stock default
(`$mod+Return` terminal, `$mod+d` menu, `$mod+Shift+q` kill, `$mod+f`
fullscreen, `$mod+r` resize mode, workspaces/scratchpad, …).

### Resolution presets — `$mod+F10/F11/F12`

Intended for games/streaming on the 4K panel. The iGPU composites at the low
resolution and the panel's fixed scaler upscales to 3840×2160 — so every
framebuffer px is 2 (1080p) or 3 (720p) physical px. `set-res.sh` re-derives
**everything** per preset from `machine/theme.nix` and applies it
live: fonts (sway/waybar/mako/ghostty/GTK/swayosd), bar size, notification
margins, cursor size, mouse speed, popup anchors — open terminals even update
in place (ghostty SIGUSR2 config reload).

| Key | Resolution | Use |
|---|---|---|
| `$mod+F10` | 1280×720 | native game play |
| `$mod+F11` | 1920×1080 | game streaming |
| `$mod+F12` | 3840×2160 (EDID) | normal desktop |

Note: a terminal that was manually zoomed (`Ctrl+=`/`Ctrl+-`) drops out of the
font cascade — press `Ctrl+0` in it (reset font size) to rejoin.

### Help & utilities

| Key | Action |
|---|---|
| `$mod+F1` | searchable keybind overview (`keys.sh` → fuzzel `--dmenu`) |
| `$mod+n` | notification history (mako buffer via fuzzel viewer) |
| `$mod+o` | wlsunset nightlight toggle (warm orange ~4000K, no timer) |
| `$mod+Shift+Return` | new Zen browser window |
| `$mod+b` | blueman bluetooth manager (2×-scaled floating popup) |

### IME (works in every app)

| Key | Action |
|---|---|
| `$mod+Shift+t` | toggle English ⇄ Pinyin (fcitx5; sway intercepts before the app, so VS Code/Electron have no blind spot) |

### Screenshots — clipboard-only (Windows-snipping style)

| Key | Action |
|---|---|
| `Print` | whole screen → clipboard |
| `Ctrl+Print` | focused window → clipboard |
| `$mod+Shift+s` | snip: rectangle select with **live pixel measurements** |

### Focus, move & splits — vim directions

`$mod+h/j/k/l` = focus left/down/up/right (arrows work too). Move windows with
`$mod+Shift+h/j/k/l`. `$mod+semicolon` = horizontal split, `$mod+v` = vertical
split (stock). The resize mode (`$mod+r`) also uses vim keys.

### Hardware keys & other bindings

- `XF86Audio*` / `XF86MonBrightness*` → swayosd on-screen popups;
  play/pause/next/prev → playerctl.
- caps → Esc via `keyd` (system-wide).
- `$mod+Shift+e` quits sway (confirmation nag); `$mod+Shift+c` reloads config.
- Window rules: Signal/Discord → workspace 9, Slack → 8; pavucontrol/blueman
  float as 2×-scaled popups anchored to their tray icons; Dolphin dialogs float.
- Bar sits at the **bottom**; focus follows mouse; the cursor never auto-hides.

## Layout

```
flake.nix               # entry: nixpkgs pins, system, home-manager, machine/ imports
configuration.nix       # machine-level glue (env vars via machine/theme.nix)
hardware-configuration.nix  # generated by nixos-generate-config (machine-specific)
machine/                # ← EVERYTHING per-device / per-user (see table above)
  identity.nix          # username, hostname
  theme.nix             # palette, fonts, scales, popup anchors (pure data)
  hardware.nix          # XPS 9570 tuning: undervolt, thermald, keyd
  printing.nix          # Brother MFC-J6555DW
  fcitx5.nix            # Pinyin IME (system + user + sway wiring)
  vscode.nix            # VS Code config + extensions
  resolution.nix        # $mod+F10/11/12 presets (generates set-res.sh)
  gtk4-theme.nix        # GTK4 CSS, generated from theme.nix palette
  set-res.sh            # template read by resolution.nix
modules/                # generic, reusable on any machine
  base.nix              # boot, firmware blacklist, locale, users, system packages
  desktop.nix           # sway/regreet/GTK+Qt theming plumbing, fonts, portals
  apps.nix dev.nix audio.nix gaming.nix
  hardware-generic.nix  # graphics, bluetooth, fwupd — anything machine-agnostic
home/                   # per-user (session) config
  default.nix           # home-manager hub: packages, shell, sway, waybar, theming
  sway/ waybar/ fuzzel/ kanshi/ swayosd/ cursor/ kvantum/ color-schemes/
```