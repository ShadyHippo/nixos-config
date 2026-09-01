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
    # blueman: 2x-scaled like the Cura wrapper — blueman is GTK3 so QT_SCALE_FACTOR
    # ignores it; GDK_SCALE=2 doubles the whole UI (buttons included). Wrapped at
    # package level so BOTH launch paths scale: $mod+b toggle AND the tray icon's
    # "Bluetooth Manager" menu item.
    (blueman.overrideAttrs (old: {
      postFixup = (old.postFixup or "") + ''
        wrapProgram $out/bin/blueman-manager --set GDK_SCALE ${toString sizing.display.gtk.blueman}
      '';
    }))
    joycond                       # Joy-Con pair daemon (combines L+R into one pad)
    playerctl                     # media keys
    libnotify                     # notify-send (your bash 'alert' alias)
    nfs-utils cifs-utils          # NAS mounts when needed
  ];

  system.stateVersion = "26.05";
}
