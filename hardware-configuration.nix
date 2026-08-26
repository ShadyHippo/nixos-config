# PLACEHOLDER - overwritten by `nixos-generate-config` during install (see flake.nix steps).
#
# Assumes: nvme0n1p1 = ESP (fat32, /boot), nvme0n1p2 = ext4 root labeled "nixos".
# If you partition differently, regenerate this file - don't hand-edit UUID guesses.
#
# No swap: you chose suspend-only (no hibernate). To add swap later:
#   dd if=/dev/zero of=/swapfile bs=1M count=8192
#   chmod 600 /swapfile && mkswap /swapfile && swapon /swapfile
# then add:  swapDevices = [ { device = "/swapfile"; } ];

{ ... }:

{
  fileSystems."/" =
    {
      device = "/dev/disk/by-label/nixos";
      fsType = "ext4";
    };

  fileSystems."/boot" =
    {
      device = "/dev/disk/by-label/ESP";
      fsType = "vfat";
      options = [ "fmask=0077" "dmask=0077" ];
    };

  nix.settings.max-jobs = 4;   # i5-8300H: 4c/8t
}
