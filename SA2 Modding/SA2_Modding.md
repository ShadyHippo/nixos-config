# Sonic Adventure 2 (Battle) — Modded Setup on NixOS + Steam + Proton

**STATUS: WORKING — exactly as intended as of 2026-09-08.** The full known-good
state is snapshotted in `backup/` (and `sa2b-full-backup.tar.zst` for the NAS).

## Golden rules

1. **Launch the game from Steam only.** Never "Save & Play" from the mod
   manager — the manager's sandbox has no working audio
   ("DirectSound Create Failed!").
2. **Only ever update / change mods through the Mod Manager GUI** and its
   **Install Loader** button. The loader and manager must always be from the
   same ecosystem/version — mixing versions is what broke this setup the
   first time.
3. **Never install a standalone DXVK `d3d9.dll`** into the game folder.
   Proton 10 already ships DXVK; a second copy breaks rendering.
4. Never hand-edit files in the game folder while the Mod Manager is still
   open (it overwrites on save).
5. If the game "freezes", **Alt+Tab first** — it may be a hidden modal error
   box (see Troubleshooting).

## What is in this directory

| File | What it is | Size |
|---|---|---|
| `SA2_Modding.md` | This document | — |
| `setup-sa2b.sh` | One-shot (re)installer — restores the exact working setup, idempotent | — |
| `launch-manager.sh` | Shortcut: opens SA Mod Manager inside the SA2B prefix | — |
| `SAModManager.exe` | SA Mod Manager 1.3.7 (portable, Win x64, needs .NET 8 desktop in prefix) | 21 MB |
| `backup/` | **The complete known-good payload** (loose files): the 7 mods, `mods/.modloader` (loader settings/profiles/data), launcher `Config/` | 886 MB |
| `sa2b-full-backup.tar.zst` | The same payload as a single file (tar of `backup/` + `SAModManager.exe`) — **copy this to the NAS** | 364 MB |
| `.gitignore` | Keeps `backup/` and the tarball out of git (too large) |

Regenerate the NAS tarball after any mod update:

```bash
cd ~/nixos-config/"SA2 Modding"
tar -cf - backup SAModManager.exe | zstd -3 -T0 -o sa2b-full-backup.tar.zst
```

## Current working configuration (snapshot)

- **Game**: Sonic Adventure 2, Steam App ID **213610**
  `~/.local/share/Steam/steamapps/common/Sonic Adventure 2`
- **Compatibility tool**: **Proton 10.0-4** (forced in Steam: Properties →
  Compatibility). Prefix: `~/.local/share/Steam/steamapps/compatdata/213610`
- **Mod Loader**: SA2 Mod Loader **v328** (X-Hax), installed as a replacement
  of `resource/gd_PC/DLL/Win32/Data_DLL.dll` (vanilla copy kept as
  `Data_DLL_orig.dll`). Loader settings live in
  `mods/.modloader/` — the older root-level `SA2ModLoader.ini` /
  `Codes.lst` / `Patches.json` are **legacy and ignored** by loader v328.
- **Profile** `mods/.modloader/profiles/Default.json` (SettingsVersion 3):
  - Graphics: Screen 1 (primary), 1920×1080, 60 Hz, `ScreenMode: 3`
    (as saved by the manager — don't hand-edit this value, use the GUI),
    border image enabled
  - Patches: `FramerateLimiter: false` (**required — Render Fix has its own
    frame cap**, everything else true: DisableExitPrompt, SyncLoad,
    ExtendVertexBuffer, EnvMapFix, ScreenFadeFix, CECarFix, ParticlesFix)
  - Debug: crash log on, debug file/console off
  - `EnabledMods` (load order matters):
    1. `sa2-render-fix`
    2. `SA2VolumeControls`
    3. `sasdl` (SDL2 dependency — must stay at/above Input Controls)
    4. `sa2-input-controls`
    5. `MenuOverhaul`
    6. `HD GUI for SA2`
    7. `HD Boss Titles`
  - `Codes.dat` / `Patches.dat`: compiled code lists (currently empty 11-byte
    headers — no cheat codes enabled)
- **Prefix wine deps** (check `pfx/winetricks.log`): `dotnetdesktop8`,
  `vcrun2013`, `vcrun2022` (needed for the Mod Manager GUI only)
- **`Config/UserConfig.cfg`**: the legacy Launcher.exe window config
  (`FullScreen="1"` is harmless — the mod loader controls the real window
  mode; keep it windowed/borderless in the manager anyway)

### Mod sources

| Mod | Source |
|---|---|
| SA2 Render Fix 1.5.4 | <https://github.com/shaddatic/sa2b-render-fix> |
| SA2 Input Controls 1.1.0.2 | <https://github.com/shaddatic/sa2b-input-controls> (depends on SASDL) |
| SASDL 1.0.0 | <https://github.com/shaddatic/sa2b-sdl-loader> |
| SA2 Volume Controls 1.5 | <https://gamebanana.com/mods/381193> |
| HD GUI for SA2 1.1 | <https://gamebanana.com/mods/34355> *(gui category)* |
| HD Boss Titles 1.1.1 | <https://gamebanana.com/mods/507363> |
| Menu Overhaul 1.15 | by Speeps (bundled here; no URL recorded in its mod.ini) |
| SA Mod Manager 1.3.7 | <https://github.com/X-Hax/SA-Mod-Manager/releases> |

## How it all fits together

```
Steam launch
  └─ Proton 10.0-4 (Steam Linux Runtime "sniper" container)
      └─ Launcher.exe (old SEGA launcher; Config/UserConfig.cfg)
          └─ sonic2app.exe (32-bit DX9 game)
              └─ loads resource/gd_PC/DLL/Win32/Data_DLL.dll
                  └─ THAT IS the SA2 Mod Loader (SA2ModLoader.dll copy;
                     vanilla binary preserved as Data_DLL_orig.dll)
                      ├─ reads mods/.modloader/profiles/Profiles.json
                      │    └─ → profile "Default.json" (settings + mod list)
                      ├─ applies built-in patches from the profile "Patches" dict
                      ├─ loads mods/.modloader/Codes.dat + Patches.dat (codev5 binaries)
                      └─ loads each enabled mod from mods/<folder>/mod.ini
                           └─ mods can ship DLLs, textures, code replacements
```

The **mod manager** (`SAModManager.exe`, run through the SA2B prefix because
it needs .NET 8) is the one tool that keeps loader versions, profiles,
`Codes.dat`/`Patches.dat` and the mod list consistent. Anything it writes is
authoritative.

## The incident history (why this exists — do not repeat)

1. **Loader/manager version mismatch → frozen "Now Loading" ring.**
   The loader was updated to v328 while the installed Mod Manager was older.
   v328 reads its settings from `mods/.modloader/profiles/Profiles.json`;
   the old manager had only written the legacy root-layout files
   (`SA2ModLoader.ini`, `Codes.lst`, `Patches.json`), so no `Profiles.json`
   existed anywhere. The loader then shows a **modal error box**
   ("Mod Loader settings could not be read … Profiles.json") and kills the
   game — in fullscreen the box was invisible, so it only ever looked like a
   frozen loading screen.
   *Fix: run SA Mod Manager (1.3.7) → Install Loader → Save. It creates the
   whole `mods/.modloader/` layout and compiles `Codes.dat`/`Patches.dat`.*
2. **0-byte `mods/SA2ModLoader.ini`** — leftover cruft from the mismatched
   install; ignored by v328; harmless but deleted by `setup-sa2b.sh`.
3. **"DirectSound Create Failed!"** — only ever happens when the game is
   launched *from inside the manager* (`Save & Play`): protontricks' sandbox
   doesn't provide the game's audio environment. Host audio (PipeWire +
   pipewire-pulse) is fine; **launching via Steam gives working sound.**
4. **Render Fix wants the loader's framerate patch off.** It shows
   "It is recommended that you disable the Mod Loader's Lock Framerate
   patch…" — uncheck `Game Config → Patches → Limit Framerate` in the
   manager (already done in this snapshot: `FramerateLimiter: false`).
   Render Fix implements its own frame cap.

## Reproducing from scratch (new laptop playbook)

Prereq: the machine runs this same nixos-config (Steam native +
`proton-ge-bin` in `extraCompatPackages` + protontricks + p7zip, see
`modules/gaming.nix`). Rebuild and log out/in once so Steam sees the
compat tools.

1. **Install the game via Steam**, then in the game's properties:
   Compatibility → *Force the use of a specific Steam Play tool* →
   **Proton 10.0-4** (GE-Proton also exists but SA2B is maintained against
   official Proton here).
2. **Launch the game once (vanilla)** and quit — this creates the Proton
   prefix and runs Steam's vcredist install script.
3. **Copy the bundle from the NAS** (or USB) onto the new machine:
   ```bash
   mkdir -p ~/nixos-config
   # copy "SA2 Modding" (or just the tarball) over, then:
   cd ~/nixos-config/"SA2 Modding"
   tar -xf sa2b-full-backup.tar.zst   # if starting from the single file
   ```
4. **Run the installer**:
   ```bash
   cd ~/nixos-config/"SA2 Modding"
   ./setup-sa2b.sh --install-winetricks   # first run on a new machine
   ./setup-sa2b.sh                        # any later run (fast, idempotent)
   ```
   It backs up the vanilla `Data_DLL.dll`, installs loader v328, restores all
   7 mods + `.modloader` settings (including the profile with your exact
   graphics/patches/mod order), fixes the profile's `GamePath` for the new
   machine, and restores the launcher configs.
5. **Launch from Steam. Done.**

Optional GUI check on a new machine:
```bash
~/nixos-config/"SA2 Modding"/launch-manager.sh
```

## Daily-use commands

```bash
sa2-mods          # zsh alias → opens SA Mod Manager in the SA2B prefix
sa2-setup         # zsh alias → re-run the setup installer (idempotent)

# without aliases:
~/nixos-config/"SA2 Modding"/launch-manager.sh
~/nixos-config/"SA2 Modding"/setup-sa2b.sh [--install-winetricks]

# the underlying manager command (what the alias does):
protontricks-launch --appid 213610 ~/nixos-config/"SA2 Modding"/SAModManager.exe
# prefix wine deps (only ever needed once per new prefix):
protontricks 213610 dotnetdesktop8 vcrun2013 vcrun2022
```

The `sa2-mods` / `sa2-setup` aliases live in
`~/nixos-config/home/default.nix` (`programs.zsh.shellAliases`) — apply with
your usual nixos-config rebuild.

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| Ring frozen on "Now Loading", no visible box | A modal error box is open *behind* the game (loader uses modal dialogs mid-boot) | Alt+Tab / check other windows; dismiss the box; fix whatever it complains about |
| "Mod Loader settings could not be read … Profiles.json" | `.modloader/profiles/` missing or corrupted | Run `setup-sa2b.sh` to restore, or in the manager: re-save settings |
| "DirectSound Create Failed!" | Game launched from inside the manager | Click OK, close manager, launch from Steam |
| SEGA/"Now Loading" freeze in true fullscreen | Known SA2B exclusive-fullscreen issue on some setups | Keep *Windowless Border Mode* (or Windowed) in manager Game Config; leave `UserConfig.cfg` alone |
| "It is recommended that you disable the Mod Loader's Lock Framerate patch…" | Render Fix vs loader `Limit Framerate` patch conflict | Manager → Game Config → Patches → uncheck **Limit Framerate** → Save |
| Game runs at double speed | No framerate cap anywhere (60 Hz screens are safe; >60 Hz monitors double-speed the game) | Never disable BOTH the loader patch and Render Fix's frame cap |
| Stuck game process won't die | wineserver keeps prefix alive | `pkill -9 -f sonic2app; pkill -9 wineserver` (kills that prefix's whole wine session) |
| Loader seems gone after Steam "Verify integrity" | Steam restored vanilla `Data_DLL.dll` | Just re-run `./setup-sa2b.sh` (it will re-install the loader; `Data_DLL_orig.dll` survives verification) |
| Want to debug a boot hang | Logs are off by default | Manager → Game Config → enable **Debug File**; log + crash dumps appear in the game folder on next run (needs a clean exit, not a force-kill) |
| Everything broken, give up | — | Steam verify (restores vanilla) → re-run `setup-sa2b.sh` |

## Moving laptops — checklist

- [ ] Copy `sa2b-full-backup.tar.zst` to the NAS (this is the only artifact
      that matters; the git repo carries the scripts).
- [ ] On the new machine: clone nixos-config, rebuild, reboot.
- [ ] Steam: install SA2, force Proton 10.0-4, launch once, quit.
- [ ] Copy tarball into `~/nixos-config/"SA2 Modding"/`, extract it.
- [ ] `./setup-sa2b.sh --install-winetricks`
- [ ] Launch from Steam. Play.

## Files you should never hand-edit (use the manager)

- `mods/.modloader/profiles/*.json` — settings/profiles (manager writes them;
  `setup-sa2b.sh` only fixes the machine-specific `GamePath`)
- `mods/.modloader/Codes.dat`, `Patches.dat` — compiled binaries (codev5)
- `resource/gd_PC/DLL/Win32/Data_DLL.dll` vs `Data_DLL_orig.dll` — never
  delete the `_orig` backup
