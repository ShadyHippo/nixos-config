{ pkgs, ... }:

{
  # Result of the app-audit poll. Everything selected lives here; everything
  # unselected is one line away if you ever want it back.
  environment.systemPackages = with pkgs; [
    # communication & streaming
    signal-desktop discord vivaldi moonlight-qt

    # playback & music tools
    mpv vlc kid3 yt-dlp

    # office
    libreoffice

    # creative
    gimp
    # Cura: Qt6 app, wrapped with QT_SCALE_FACTOR=1.5 for 4K panel.
    (cura-appimage.overrideAttrs (old: {
      postFixup = (old.postFixup or "") + ''
        wrapProgram $out/bin/cura --set QT_SCALE_FACTOR 1.5
      '';
    }))

    # capture & streaming — OBS alongside Kooha (home/default.nix). Wrapped
    # with input-overlay so gamepad presses can be burned into the recording
    # for the quickshell#1189 demo, instead of a side-by-side hardwares-tester
    # window the menu then covers. Screen capture goes through the PipeWire
    # portal (xdg.portal.wlr, modules/desktop.nix); input-overlay reads pads
    # via SDL — its libuiohook keyboard/mouse backend is X11-only — so map
    # buttons in the plugin's own editor. Qt6 scales via global QT_SCALE_FACTOR.
    (wrapOBS {
      plugins = with obs-studio-plugins; [ input-overlay ];
    })

    # disks (GNOME left behind)
    gparted smartmontools nvme-cli gdu

    # printing & scanning GUIs — drivers/backends configured in machine/printing.nix
    naps2

    # dev CLI
    zellij gitui fzf parallel pv

    # python runtime (basic, stdlib only). For project work, make a venv:
    #   python3 -m venv .venv && source .venv/bin/activate
    python3

    # media conversion — heicToJpg uses heif-convert (stock ffmpeg lacks HEIC
    # demuxer, no libheif wired in). Free codecs only.
    ffmpeg
    libheif

    # viewers & transfer
    imv kdePackages.gwenview

    # lifestyle
    hyfetch ani-cli
  ];

  # mesh VPN; run `sudo tailscale up` post-install
  services.tailscale.enable = true;

  # LocalSend (LAN file transfer) — the module installs the package and opens
  # port 53317 (TCP + UDP) in the firewall.
  programs.localsend.enable = true;

  # printing/sane services live in machine/printing.nix

  # iPhone over USB (photo transfer -> heicToJpg workflow)
  services.usbmuxd.enable = true;
}
