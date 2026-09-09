{
  description = "NixOS configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    zen-browser = {
      url = "github:youwen5/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-flatpak = {
      url = "github:gmodena/nix-flatpak";
    };
  };

  outputs = { self, nixpkgs, nixpkgs-unstable, home-manager, ... }@inputs:
    let
      system = "x86_64-linux";
      identity = import ./machine/identity.nix;
    in
    {
      nixosConfigurations.${identity.hostname} = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = {
          inherit inputs;
          # Unstable nixpkgs for system modules (nerd-fonts 3.5.0+ needed for
          # complete Material Design Icons glyph block).
          unstable = import nixpkgs-unstable {
            inherit system;
            config.allowUnfree = true;
          };
        };
        modules = [
	  ./hardware-configuration.nix
          ./configuration.nix
          ./modules/base.nix
          ./modules/apps.nix
          ./modules/audio.nix
          ./modules/desktop.nix
          ./modules/dev.nix
          ./modules/gaming.nix
          ./modules/hardware-generic.nix
          ./machine/hardware.nix
          ./machine/printing.nix
          ./machine/fcitx5.nix
          ./machine/vscode.nix
	  home-manager.nixosModules.home-manager
	  {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.extraSpecialArgs = { inherit inputs; };
            # Backup extension: HM aborts activation if a target exists as a
            # real file.
            home-manager.backupFileExtension = "bak";
            home-manager.users.${identity.username} = {
	      imports = [
                ./home
                inputs.nix-flatpak.homeManagerModules.nix-flatpak
              ];

	      _module.args.unstable = import nixpkgs-unstable {
                inherit system;
		config.allowUnfree = true;
	      };
	    };
	  }
        ];
      };
    };
}
