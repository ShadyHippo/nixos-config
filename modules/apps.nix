{ pkgs, ... }:

{
  # Result of the app-audit poll. Everything selected lives here; everything
  # unselected is one line away if you ever want it back.
  environment.systemPackages = with pkgs; [
    # communication & streaming
    signal-desktop discord vivaldi moonlight-qt

    # playback & music tools
    mpv vlc kid3 yt-dlp

    # creative
    gimp
    cura-appimage          # upstream went AppImage-only; this is the packaged form

    # disks (GNOME left behind)
    gparted smartmontools nvme-cli gdu

    # printing & scanning — Brother MFC-J6550DW: prints via driverless IPP,
    # scanning uses brscan5 backend (NAPS2 UI)
    naps2 brscan5

    # dev CLI
    zellij gitui fzf ripgrep parallel pv

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
