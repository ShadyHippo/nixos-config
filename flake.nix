{
  description = "hippo's NixOS config";

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
    in
    {
      nixosConfigurations.hippo-xps = nixpkgs.lib.nixosSystem {
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
          # Pin moonlight-qt to 6.0.1 — 6.1.0 has a regression bug.
          { nixpkgs.overlays = [
              (final: prev: {
                moonlight-qt = prev.moonlight-qt.overrideAttrs (old: {
                  version = "6.0.1";
                  src = prev.fetchFromGitHub {
                    owner = "moonlight-stream";
                    repo = "moonlight-qt";
                    rev = "v6.0.1";
                    hash = "sha256-zrl8WPXvQ/7FTqFnpwoXEJ85prtgJWoWNsdckw5+JHI=";
                  };
                  patches = [
                    (prev.fetchpatch {
                      url = "https://github.com/moonlight-stream/moonlight-qt/commit/d73df12367749425b86b72c250bb0fba13ddfd29.patch";
                      hash = "sha256-RIrQpZWbwUHs1Iwz/pXfXgshJeHYrzGxuaR5mRG85QY=";
                    })
                  ];
                });
              })
            ];
          }
	  ./hardware-configuration.nix
          ./configuration.nix
          ./modules/base.nix
          ./modules/apps.nix
          ./modules/audio.nix
          ./modules/desktop.nix
          ./modules/dev.nix
          ./modules/gaming.nix
          ./modules/hardware.nix
          ./modules/printing.nix
	  home-manager.nixosModules.home-manager
	  {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.extraSpecialArgs = { inherit inputs; };
            # Backup extension: HM aborts activation if a target exists as a
            # real file (fcitx5's profile did this).
            home-manager.backupFileExtension = "bak";
            home-manager.users.hippo = {
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
