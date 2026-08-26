# XPS 15 9570 — NixOS 26.05 (stable) + Sway
#
# INSTALL STEPS (run these when you make the jump):
#
#   1. Boot the NixOS 26.05 ISO (USB). Wi-Fi: `sudo nmcli device wifi connect SSID`.
#   2. Partition (whole NVMe, UEFI):
#        sudo parted /dev/nvme0n1 -- mklabel gpt
#        sudo parted /dev/nvme0n1 -- mkpart ESP fat32 1MiB 1GiB
#        sudo parted /dev/nvme0n1 -- set 1 esp on
#        sudo parted /dev/nvme0n1 -- mkpart primary 1GiB 100%
#        sudo mkfs.fat -F32 /dev/nvme0n1p1
#        sudo mkfs.ext4 -L nixos /dev/nvme0n1p2
#        sudo mount /dev/disk/by-label/nixos /mnt
#        sudo mkdir -p /mnt/boot && sudo mount /dev/nvme0n1p1 /mnt/boot
#   3. Clone this repo and generate hardware-configuration.nix (real UUIDs):
#        sudo nix-env -iA nixos.git   # if git missing on ISO
#        git clone <this-repo> ~/desktop_config && cd ~/desktop_config/nix
#        sudo nixos-generate-config --root /mnt --dir .
#        # -> overwrites ./hardware-configuration.nix and ./configuration.nix;
#        #    `git checkout configuration.nix` to restore ours (keep hardware-configuration.nix!)
#   4. Set a real password: edit modules/base.nix initialPassword or run
#        nix-shell -p mkpasswd  # then replace initialPassword with
#                               # initialHashedPassword = "$(mkpasswd -m sha-512)"
#   5. Install:
#        sudo nixos-install --flake .#xps15
#   6. Reboot. Log in at the tuigreet prompt, sway starts.
#
# POST-INSTALL CHECKLIST:
#   - passwd                       (change from 'changeme')
#   - gh auth login                (restores github credentials for git)
#   - mise use -g node@lts go@latest python@3.12 ...   (your toolchains)
#   - git clone <my_scripts repo> ~/.local/bin/my_scripts
#   - Drop the Fire Emblem PoR texture pack into
#       ~/.local/share/dolphin-emu/Load/Textures/GFEM01/
#     (verify the game ID shown in Dolphin's title bar matches GFEM01; EU disc = GFEP01)
#   - Verify NVIDIA is off: cat /sys/bus/pci/devices/0000:01:00.0/power/runtime_status
#     -> should say "suspended"
#   - Ctrl+Super+A toggles English <-> Pinyin (preconfigured, no fcitx5-configtool trip needed)

{
  description = "hippo's XPS 15 9570 - NixOS 26.05 stable, Sway, minimal";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    # Fast lane: only used to swap individual fast-moving packages (vscode).
    # Everything else stays on stable.
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";

    # Neovim nightly - you want SOTA features for plugins.
    # Replaces pkgs.neovim everywhere.
    neovim-nightly-overlay = {
      url = "github:nix-community/neovim-nightly-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Zen browser is not packaged in nixpkgs stable; this community flake is
    # actively maintained and pinned here so the rest stays pure stable.
    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };
  };

  outputs = { self, nixpkgs, nixpkgs-unstable, neovim-nightly-overlay, home-manager, zen-browser, ... }@inputs:
    let
      system = "x86_64-linux";
    in
    {
      nixosConfigurations.xps15 = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          ./configuration.nix
          {
            nixpkgs.overlays = [
              # pkgs.neovim -> nightly build
              neovim-nightly-overlay.overlays.default
              # pkgs.vscode -> current unstable (tracks MS biweekly releases)
              (final: prev: {
                vscode = nixpkgs-unstable.legacyPackages.${prev.system}.vscode;
              })
            ];
          }
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.extraSpecialArgs = { inherit inputs; };
            home-manager.users.hippo = import ./home;
          }
        ];
      };
    };
}
