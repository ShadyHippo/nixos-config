{ pkgs, ... }:

{
  # Result of the app-audit poll. Everything selected lives here; everything
  # unselected is one line away if you ever want it back.
  environment.systemPackages = with pkgs; [
    # communication & streaming
    signal-desktop discord vivaldi moonlight-qt

    # playback & music tools
    mpv vlc kid3 yt-dlp

    # office — spreadsheet & word processing (wish list: don't get caught without)
    libreoffice

    # creative
    gimp
    # Cura: upstream went AppImage-only; this is the packaged form. Wrapped
    # with QT_SCALE_FACTOR=1.5 — Qt6 app, on the 4K panel at sway scale 1 the
    # UI is too small. Scoped to Cura only; other Qt apps keep scale 1.0.
    (cura-appimage.overrideAttrs (old: {
      postFixup = (old.postFixup or "") + ''
        wrapProgram $out/bin/cura --set QT_SCALE_FACTOR 1.5
      '';
    }))

    # disks (GNOME left behind)
    gparted smartmontools nvme-cli gdu

    # printing & scanning — Brother MFC-J6550DW: prints via driverless IPP,
    # scanning uses brscan5 backend (NAPS2 UI)
    naps2 brscan5

    # dev CLI
    zellij gitui fzf ripgrep parallel pv

    # python runtime (basic, stdlib only). For project work, make a venv:
    #   python3 -m venv .venv && source .venv/bin/activate
    python3

    # media conversion — my_scripts transcode stack
    # NOTE: stock nixpkgs ffmpeg has NO HEIC demuxer (no libheif wired in),
    # so heicToJpg's ffmpeg attempt fails and its heif-convert fallback does
    # the real work. Free codecs only — no ffmpeg-full/nonfree needed.
    ffmpeg
    libheif

    # viewers & transfer — imv backs your my_scripts `img` command
    imv localsend

    # lifestyle
    hyfetch ani-cli
  ];

  # mesh VPN for the remote-agent workflow; run `sudo tailscale up` post-install
  services.tailscale.enable = true;

  services.printing.enable = true;
  hardware.sane.enable = true;
  hardware.sane.extraBackends = [ pkgs.brscan5 ];

  # iPhone over USB (photo transfer -> heicToJpg workflow)
  services.usbmuxd.enable = true;
}
