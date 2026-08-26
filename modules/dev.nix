{ ... }:

{
  # ---- Docker -----------------------------------------------------------------
  # Main use: running Maki (and other agents) sandboxed with yolo privileges -
  # the container boundary IS the safety net, so prompt-free mode stays contained
  # to whatever directory you bind-mount.
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
  # Lets unpatched prebuilt Linux binaries run: mise-installed toolchains,
  # VS Code's extension host/server bits, standalone agent binaries, AppImages.
  # Without this you get cryptic "No such file or directory" on perfectly
  # existing ELF files (missing dynamic loader path).
  programs.nix-ld.enable = true;
}
