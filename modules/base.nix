{ config, pkgs, lib, ... }:

let
  sizing = import ./sizing.nix;   # all scaling decisions (see file)
  theme  = import ./theming.nix;  # palette + theme names (see file)
in
{
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Kernel modules we never want loaded. nouveau is known to panic on the 9570,
  # and nothing should ever touch the GTX 1050 Ti (see modules/hardware.nix).
  boot.blacklistedKernelModules = [
    "nouveau" "rivafb" "nvidiafb" "rivatv" "nv"
    "nvidia" "nvidia-drm" "nvidia-modeset" "nvidia-uvm"
  ];
  # Lock modprobe out of loading nvidia even by alias/probe.
  boot.extraModprobeConfig = ''
    install nvidia /bin/false
  '';

  time.timeZone = "America/Detroit";
  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
  };

  networking.networkmanager.enable = true;

  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = false;   # flip to true temporarily if you need password ssh while setting up keys
  };

  security.polkit.enable = true;

  # Steam / VS Code are unfree.
  nixpkgs.config.allowUnfree = true;

  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    auto-optimise-store = true;
  };
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };

  users.users.hippo = {
    isNormalUser = true;
    description = "hippo";
    extraGroups = [ "wheel" "networkmanager" "audio" "video" "input" "docker" "scanner" "lp" ];
    shell = pkgs.zsh;
  };

  environment.systemPackages = with pkgs; [
    git vim wget curl htop btop
    pciutils usbutils lshw        # hardware poking
    powertop                      # diagnostics ONLY - TLP does the writing (your rule)
    lm_sensors                    # `sensors` - real temp/fan readings (btop + debugging)
    brightnessctl                 # screen backlight (bound to XF86 keys in sway)
    grim                          # screenshots (slurp lives in configuration.nix - overridden there with the -x crosshair/cursor-hide patches)
    wl-clipboard                  # wayland copy/paste
    pavucontrol                   # per-app volume
    # blueman: 2x-scaled via GDK_SCALE — blueman is GTK3 so QT_SCALE_FACTOR
    # ignores it. GDK_BACKEND=x11 (XWayland) is required: GTK3's Wayland backend
    # ignores GDK_SCALE (verified). The manager is wrapped in a shim that reads
    # the scale from ~/.config/sway/preset (written by set-res.sh on every
    # F10/F11/F12 switch), defaulting to the 4K scale — so BOTH launch paths
    # ($mod+b and the tray icon) match whatever resolution is active.
    (blueman.overrideAttrs (old: {
      postFixup = (old.postFixup or "") + ''
        mv $out/bin/blueman-manager $out/bin/.blueman-manager-real
        cat > $out/bin/blueman-manager <<'SHIM'
        #!/bin/sh
        # GDK_SCALE from the resolution preset (set-res.sh), fallback = 4K scale.
        [ -f "$HOME/.config/sway/preset" ] && . "$HOME/.config/sway/preset"
        export GDK_BACKEND=x11
        export GDK_SCALE="''${SCALE:-${toString sizing.display.gtk.blueman}}"
        exec "$(dirname "$0")/.blueman-manager-real" "$@"
        SHIM
        chmod +x $out/bin/blueman-manager
      '';
    }))
    joycond                       # Joy-Con pair daemon (combines L+R into one pad)
    playerctl                     # media keys
    libnotify                     # notify-send (your bash 'alert' alias)
    nfs-utils cifs-utils          # NAS mounts when needed
  ];

  system.stateVersion = "26.05";
}
