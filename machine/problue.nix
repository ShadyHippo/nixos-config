# ─────────────────────────────────────────────────────────────────────────────
# PROBLUE — Switch Pro Controller wired cable pairing (machine-specific).
#
# Adds, for THIS machine:
#   1. patched `hid_nintendo` kernel module (passive over USB, so bluetoothd's
#      procon plugin is the only writer on the controller's hidraw; with an
#      opt-in `wired_mode` sysfs switch that instead drives a wired Pro
#      Controller as a normal gamepad for low-latency play)
#   2. BlueZ 5.86 with the procon plugin (wired pairing / link-key storage)
#   3. `problue-wire-switch`, the $mod+Shift+w toggle for (1), so the choice is
#      "decide, then plug in" — the switch is read at probe time and does not
#      persist across reboot (default OFF = Bluetooth pairing).
#
# WHY THIS DOES NOT REBUILD THE KERNEL:
#   hid_nintendo is a loadable module (CONFIG_HID_NINTENDO=m) and our patch
#   touches exactly one file (drivers/hid/hid-nintendo.c). So we skip
#   boot.kernelPatches entirely and build ONLY that module against the stock
#   kernel's `dev` output, then hand it to boot.extraModulePackages. Same
#   install path + a lower meta.priority means it wins over the in-tree .ko.xz
#   in pkgs.buildEnv (system.modulesTree). The kernel itself stays the stock,
#   binary-cached 6.18.46 — so hid-nintendo fixes cost seconds, not a 2h kernel
#   rebuild. This is the nixpkgs manual's "Developing kernel modules" recipe
#   and the wiki's "Patching a single In-tree kernel module".
#
#   LIMIT: this only holds while the change stays inside modular driver code.
#   Touch a header the built-in kernel uses and it has to go back through
#   boot.kernelPatches (see git history for that version).
#
# BlueZ is userspace, so its patch is just a small bluez rebuild either way.
#
# Patches live in ../patches/ (tracked in git) and target kernel 6.18.46 +
# BlueZ 5.86 — the nixos-26.05 pin defaults. If the kernel series or bluez
# version ever changes, re-base these patches; both builds fail loudly if they
# stop applying.
#
# Delete this file (and its import in flake.nix) on machines without the Switch
# Pro Controller wiring.
# ─────────────────────────────────────────────────────────────────────────────
{ pkgs, lib, config, ... }:
let
  kernel = config.boot.kernelPackages.kernel;

  identity = import ./identity.nix;

  # Opt-in wired USB input toggle. Needs write access to the driver's
  # /sys/bus/hid/drivers/nintendo/wired_mode, hence the sudoers rule below.
  # PATH gets coreutils + libnotify for the tools the script uses.
  wireSwitchPath = pkgs.lib.makeBinPath [
    pkgs.coreutils
    pkgs.libnotify
  ];

  problueWireSwitch = pkgs.writeShellScriptBin "problue-wire-switch" (''
    export PATH="${wireSwitchPath}:$PATH"
  '' + builtins.readFile ./problue-wire-switch.sh);

  hidNintendoPatched = pkgs.stdenv.mkDerivation {
    pname = "hid-nintendo-problue";
    inherit (kernel) version postPatch;
    inherit (kernel) src;

    patches = [ ../patches/problue-hid-nintendo-passive-6.18.46.patch ];

    # Kernel modules must not get the distro's userland hardening flags.
    # Same set the kernel derivation itself disables.
    hardeningDisable = [ "bindnow" "format" "fortify" "stackprotector" "pic" ];

    # `M=drivers/hid` builds every hid driver; we only need xz to match the
    # in-tree module's filename (CONFIG_MODULE_COMPRESS_XZ=y) so it can replace
    # it.
    nativeBuildInputs = kernel.nativeBuildInputs ++ kernel.moduleBuildDependencies ++ [ pkgs.xz ];

    # commonMakeFlags pins CC/LD/AR/... to exactly the toolchain the kernel was
    # built with, so vermagic and Module.symvers line up. Passed as an explicit
    # shell array: a `makeFlags` attribute would be stringified into one
    # argument, and make would then swallow it whole as `CC=...`.
    buildPhase = ''
      runHook preBuild

      builtKernel=${kernel.dev}/lib/modules/${kernel.modDirVersion}/build
      cp "$builtKernel/Module.symvers" .
      cp "$builtKernel/.config"        .
      cp "${kernel.dev}/vmlinux"       .

      makeFlagsArray=( ${lib.escapeShellArgs kernel.commonMakeFlags} -j"$NIX_BUILD_CORES" )

      make "''${makeFlagsArray[@]}" modules_prepare
      make "''${makeFlagsArray[@]}" M=drivers/hid modules

      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall

      make "''${makeFlagsArray[@]}" \
        INSTALL_MOD_PATH="$out" \
        INSTALL_MOD_DIR=kernel/drivers/hid \
        INSTALL_MOD_STRIP=1 \
        XZ="${pkgs.xz}/bin/xz -T$NIX_BUILD_CORES" \
        M=drivers/hid modules_install

      # Keep only our module: installing all of drivers/hid would put every
      # other hid driver into extraModulePackages as well.
      find "$out" -name '*.ko*' ! -name 'hid-nintendo.ko*' -delete

      runHook postInstall
    '';

    meta = {
      description = "Patched hid-nintendo kernel module (ProBlue USB passive mode)";
      # Lower number wins in pkgs.buildEnv, which is how this shadows the
      # in-tree hid-nintendo.ko.xz despite having the identical path.
      priority = -10;
      license = lib.licenses.gpl2Only;
      platforms = lib.platforms.linux;
    };
  };
in
{
  # ---- 1. Kernel module: hid_nintendo passive over USB ------------------------
  # With the wired_mode switch (below) opting a wired Pro Controller into full
  # driver handling instead of passivity.
  boot.extraModulePackages = [ hidNintendoPatched ];

  # ---- 2. BlueZ: procon cable-pairing plugin ----------------------------------
  # Stock BlueZ 5.86 + the procon cable-pairing patch (profiles/input/procon.{c,h},
  # sixaxis wiring, key storage). Appends to the upstream patch list rather than
  # replacing it. UserspaceHID + powerOnBoot are already set in
  # modules/hardware-generic.nix and are not duplicated here.
  hardware.bluetooth.package = pkgs.bluez.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [ ../patches/problue-bluez-procon-5.86.patch ];
  });

  # ---- 3. Wired/Bluetooth mode toggle (hotkey: $mod+Shift+w) ------------------
  environment.systemPackages = [ problueWireSwitch ];

  # NOPASSWD scoped to this one script — the hotkey runs without a terminal to
  # prompt on, so it cannot answer a password prompt. Both the store path and
  # the system path are listed so it works whether invoked via PATH or directly.
  # (A rule for the ~/.config symlink would be refused: user-owned path.)
  security.sudo.extraRules = [{
    users = [ identity.username ];
    commands = [
      { command = "${problueWireSwitch}/bin/problue-wire-switch"; options = [ "NOPASSWD" ]; }
      { command = "/run/current-system/sw/bin/problue-wire-switch"; options = [ "NOPASSWD" ]; }
    ];
  }];
}
