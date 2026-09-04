{ ... }:

{
  # ---- Docker -----------------------------------------------------------------
  # Main use: running Maki (and other agents) sandboxed with yolo privileges.
  # Container boundary is the safety net.
  virtualisation.docker = {
    enable = true;
    enableOnBoot = true;
    autoPrune = {
      enable = true;
      dates = "weekly";
    };
  };
  # membership granted in modules/base.nix ("docker" group)

  # ---- nix-ld ------------------------------------------------------------------
  # Lets unpatched prebuilt Linux binaries run (mise toolchains, VS Code
  # extensions, standalone agent binaries, AppImages).
  programs.nix-ld.enable = true;
}
