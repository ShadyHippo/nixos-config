# User-scope packages, desktop-entry overrides, default apps, flatpak.
# System-scope packages live in configuration.nix and modules/. Locally patched
# packages (quickshell, jellyfin-desktop, slurp) are defined ONCE in
# configuration.nix's nixpkgs.overlays — referencing the package by name here
# picks up the patched build.
{ pkgs, ... }:

let
  theme = import ../machine/theme.nix;
in
{
  home.packages = with pkgs; [
    ghostty                # terminal
    qalculate-gtk          # calculator (floating window rule exists for it)
    jq                     # used by sway screenshot/res scripts

    # Sway session binaries (fuzzel, waybar, kanshi, swaylock, swayidle, mako)
    # come from programs.sway.extraPackages in modules/desktop.nix, so they sit
    # on the sway session's PATH — not duplicated here.
    nwg-displays           # GUI monitor arranger — SESSION-ONLY, never saved
    swayosd                # volume/brightness OSD popups
    libpulseaudio          # pactl, for low-level audio control
    networkmanagerapplet   # nm-applet: wifi tray menu + secrets agent
    wlsunset               # nightlight (orange), hotkey-only toggle ($mod+o)
    polkit_gnome           # polkit-gnome-authentication-agent-1 (root prompts)
    fastfetch              # system info fetch
    imagemagick            # convert (required by scripts/build_db.py)
    libwebp                # cwebp (required by scripts/build_db.py)
    kdePackages.dolphin    # file manager
    # Official Jellyfin desktop client (Qt6 + libmpv) — the patched build from
    # configuration.nix's overlay (injection-race + #958 A/B swap graft;
    # details there). Gamepad navigation itself is jellyfin-web's TV display
    # mode driven by the client's own SDL input — one-time setup:
    # Settings → Display → TV, Controls → Gamepad.
    jellyfin-desktop
    pavucontrol            # per-app volume (XWayland wrapper via launch script)
    # Fuzzel/app-menu launches hit the package .desktop (plain `pavucontrol`),
    # losing the GDK_SCALE/XWayland env → unscaled native window. Same env as
    # pavucontrol-toggle.sh; reads the resolution preset SCALE set by set-res.sh.
    (pkgs.writeShellScriptBin "pavucontrol-scaled" ''
      [ -f "$HOME/.config/sway/preset" ] && . "$HOME/.config/sway/preset"
      exec env GDK_BACKEND=x11 GDK_SCALE="''${SCALE:-${toString theme.display.gtk.xwayland}}" pavucontrol
    '')
    # Kooha (GTK4/libadwaita screen recorder). GTK4's Wayland backend ignores
    # GDK_SCALE, so — like pavucontrol — it runs on XWayland with GDK_SCALE to
    # match the 4K@scale-1 panel. Reads the resolution-preset SCALE; the desktop
    # entry below points fuzzel at this wrapper.
    kooha
    (pkgs.writeShellScriptBin "kooha-scaled" ''
      [ -f "$HOME/.config/sway/preset" ] && . "$HOME/.config/sway/preset"
      exec env GDK_BACKEND=x11 GDK_SCALE="''${SCALE:-${toString theme.display.gtk.xwayland}}" kooha
    '')
    # Pinta (GTK4/libadwaita raster editor, Paint.NET-style). Same GTK4-on-4K
    # situation as kooha: the Wayland backend ignores GDK_SCALE, so it runs on
    # XWayland via pinta-scaled (desktop entry below). Theming is automatic —
    # as a libadwaita app it reads ~/.config/gtk-4.0/gtk.css
    # (machine/gtk4-libadwaita.nix), so it comes up gruvbox-dark like Kooha.
    pinta
    # "$@" forwards file arguments (Exec=%F), so `pinta-scaled foo.png` and
    # "Open with → Pinta" keep working through the wrapper.
    (pkgs.writeShellScriptBin "pinta-scaled" ''
      [ -f "$HOME/.config/sway/preset" ] && . "$HOME/.config/sway/preset"
      exec env GDK_BACKEND=x11 GDK_SCALE="''${SCALE:-${toString theme.display.gtk.xwayland}}" pinta "$@"
    '')
    # Bluejay (Qt6/QML Kirigami) needs the QQC2 Desktop Style (org.kde.desktop)
    # in its QML import path, or QtQuickControls falls back to the light Basic
    # style (white window). The style paints via QStyle (kvantum) + the KDE
    # color scheme (GruvboxDark), so it matches Dolphin once present.
    (pkgs.bluejay.overrideAttrs (old: {
      buildInputs = (old.buildInputs or []) ++ [ pkgs.kdePackages.qqc2-desktop-style ];
    }))

    # Bluetooth monitoring / debugging
    bluetuith                     # TUI bluetooth manager (connect, send files, monitor)
    bluez-tools                   # btmgmt, btinfo CLI tools for scripted BT control

    # QML shell — game launcher menu (home/quickshell/). The patched build
    # (evdev gamepad input → in-process IPC dispatch; QS_GAMEPAD_IPC_TARGET /
    # QS_GAMEPAD_HOME_FUNCTION redirect) is defined ONCE in configuration.nix's
    # overlay — using anything else here would silently run stock quickshell
    # without the gamepad wiring. Disclosed prototype for
    # quickshell-mirror/quickshell#1189, not upstreamable as-is.
    quickshell
  ];

  xdg.desktopEntries.batteryscope = {
    name = "BatteryScope";
    comment = "Battery health and degradation trends";
    exec = "${pkgs.mise}/bin/mise exec -- BatteryScope";
    terminal = false;
    categories = ["Utility" "Monitor"];
    icon = "battery-full";
  };

  # Same file id as the package entry → overrides it in ~/.local/share/
  # applications, so fuzzel launches the scaled (XWayland) wrapper instead of
  # bare `pavucontrol`. Keep the original Name/Icon/Keywords for searchability.
  xdg.desktopEntries."org.pulseaudio.pavucontrol" = {
    name = "Volume Control";
    genericName = "Volume Control";
    comment = "Adjust the volume level";
    exec = "pavucontrol-scaled";
    icon = "org.pulseaudio.pavucontrol";
    terminal = false;
    categories = [ "AudioVideo" "Audio" "Mixer" "GTK" "Settings" ];
    settings.Keywords = "pavucontrol;PulseAudio;Microphone;Volume;Mixer;Audio;Settings;";
  };

  # Kooha: same file id as the package entry → fuzzel launches the scaled
  # (XWayland) wrapper. DBusActivatable is forced off so launchers actually use
  # Exec (D-Bus activation would bypass the wrapper's env). Keep the original
  # Name/Icon/Keywords for searchability.
  xdg.desktopEntries."io.github.seadve.Kooha" = {
    name = "Kooha";
    genericName = "Screen Recorder";
    comment = "Elegantly record your screen";
    exec = "kooha-scaled";
    icon = "io.github.seadve.Kooha";
    terminal = false;
    categories = [ "GTK" "GNOME" "Utility" "Recorder" ];
    settings = {
      Keywords = "Screencast;Recorder;Screen;Video;";
      DBusActivatable = "false";
      StartupNotify = "true";
    };
  };

  # Pinta: same file id as the package entry → launchers run the scaled
  # (XWayland) wrapper instead of bare `pinta`. StartupWMClass is "pinta" (the
  # binary name), NOT the desktop-file id: the XWayland shim gives the window an
  # X11 WM_CLASS and NO app_id — the same trap as Kooha (see home/sway/config).
  # Keep Name/Icon/MimeType/Keywords for searchability + file associations.
  xdg.desktopEntries."com.github.PintaProject.Pinta" = {
    name = "Pinta";
    genericName = "Image Editor";
    comment = "Easily create and edit images";
    exec = "pinta-scaled %F";
    icon = "com.github.PintaProject.Pinta";
    terminal = false;
    categories = [ "Graphics" "2DGraphics" "RasterGraphics" "GTK" ];
    mimeType = [
      "image/bmp" "image/gif" "image/jpeg" "image/jpg" "image/pjpeg" "image/png"
      "image/svg+xml" "image/tiff" "image/x-bmp" "image/x-gray" "image/x-icb"
      "image/x-ico" "image/x-png" "image/x-portable-anymap" "image/x-portable-bitmap"
      "image/x-portable-graymap" "image/x-portable-pixmap" "image/x-xbitmap"
      "image/x-xpixmap" "image/x-pcx" "image/x-targa" "image/x-tga"
      "image/openraster" "image/webp"
    ];
    startupNotify = false;
    # No top-level options for these in this home-manager release — settings
    # is the escape hatch. DBusActivatable=false so launchers honour Exec (the
    # wrapper's env); StartupWMClass="pinta" is the X11 binary class the
    # XWayland shim exposes.
    settings = {
      Keywords = "draw;drawing;paint;painting;graphics;raster;2d;";
      DBusActivatable = "false";
      StartupWMClass = "pinta";
    };
  };

  # Default applications
  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      # images → gwenview
      "image/jpeg"          = "org.kde.gwenview.desktop";
      "image/png"           = "org.kde.gwenview.desktop";
      "image/gif"           = "org.kde.gwenview.desktop";
      "image/webp"          = "org.kde.gwenview.desktop";
      "image/bmp"           = "org.kde.gwenview.desktop";
      "image/tiff"          = "org.kde.gwenview.desktop";
      "image/heic"          = "org.kde.gwenview.desktop";
      "image/heif"          = "org.kde.gwenview.desktop";
      "image/avif"          = "org.kde.gwenview.desktop";
      "image/svg+xml"       = "org.kde.gwenview.desktop";
      "image/x-xbitmap"     = "org.kde.gwenview.desktop";
      "image/x-xpixmap"     = "org.kde.gwenview.desktop";
      "image/x-icon"        = "org.kde.gwenview.desktop";
      "image/vnd.microsoft.icon" = "org.kde.gwenview.desktop";
      "image/x-portable-pixmap"  = "org.kde.gwenview.desktop";
      "image/x-tga"         = "org.kde.gwenview.desktop";
      "image/jxl"           = "org.kde.gwenview.desktop";
      "image/x-canon-cr2"   = "org.kde.gwenview.desktop";
      "image/x-canon-cr3"   = "org.kde.gwenview.desktop";
      "image/x-nikon-nef"   = "org.kde.gwenview.desktop";
      "image/x-sony-arw"    = "org.kde.gwenview.desktop";

      # .aseprite sprites → aseprite (registered by the package's
      # aseprite.xml; without this it would fall into the image/* →
      # gwenview bucket above, which can't edit sprites)
      "image/x-aseprite"     = "aseprite.desktop";

      # video → vlc
      "video/mp4"           = "vlc.desktop";
      "video/x-matroska"    = "vlc.desktop";
      "video/webm"          = "vlc.desktop";
      "video/avi"           = "vlc.desktop";
      "video/x-msvideo"     = "vlc.desktop";
      "video/quicktime"     = "vlc.desktop";
      "video/x-flv"         = "vlc.desktop";
      "video/mpeg"          = "vlc.desktop";
      "video/ogg"           = "vlc.desktop";
      "video/x-theora+ogg"  = "vlc.desktop";
      "video/3gpp"          = "vlc.desktop";
      "video/3gpp2"         = "vlc.desktop";
      "video/dvd"           = "vlc.desktop";
      "video/x-ms-wmv"      = "vlc.desktop";
      "application/x-matroska" = "vlc.desktop";
      "application/mp4"     = "vlc.desktop";
      "application/x-mpegURL"     = "vlc.desktop";
      "application/vnd.apple.mpegurl" = "vlc.desktop";
      "audio/x-mpegurl"     = "vlc.desktop";
      "audio/mpegurl"       = "vlc.desktop";
    };
  };

  # Flatpak (managed via nix-flatpak module)
  services.flatpak.packages = [
    "net.retrodeck.retrodeck"
  ];

  # EasyEffects: system-wide audio effects (EQ, compression, limiter).
  # Auto-starts with the pipewire session; dconf backing store is already
  # enabled system-wide (modules/desktop.nix) so settings persist.
  services.easyeffects.enable = true;
}
