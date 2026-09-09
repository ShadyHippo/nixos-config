{ config, pkgs, lib, ... }:

let
  identity = import ../machine/identity.nix;
in
{
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Kernel modules blacklisted: nouveau panics on this laptop (XPS 9570);
  # nothing should touch the GTX 1050 Ti (see machine/hardware.nix).
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
    settings.PasswordAuthentication = false;
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

  users.users.${identity.username} = {
    isNormalUser = true;
    description = identity.username;
    extraGroups = [ "wheel" "networkmanager" "audio" "video" "input" "docker" "scanner" "lp" ];
    shell = pkgs.zsh;
  };

  environment.systemPackages = with pkgs; [
    git vim wget curl htop btop
    pciutils usbutils lshw        # hardware poking
    powertop                      # diagnostics only (power management config lives elsewhere)
    lm_sensors                    # `sensors` - temp/fan readings (btop + debugging)
    stress-ng                     # CPU/RAM stress testing (undervolt validation)
    glmark2                       # GPU stress testing (use --backend=wayland)
    brightnessctl                 # screen backlight (bound to XF86 keys in sway)
    wl-clipboard                  # wayland copy/paste
    joycond                       # Joy-Con pair daemon (combines L+R into one pad)
    playerctl                     # media keys
    libnotify                     # notify-send
    glib.bin                      # gsettings — set-res.sh sets font-name/cursor-size live
    gsettings-desktop-schemas     # org.gnome.desktop.interface etc. (schema files for gsettings)
    nfs-utils                     # NAS mounts when needed
  ];

  system.stateVersion = "26.05";
}
