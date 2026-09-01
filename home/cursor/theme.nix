# Build a recolored Bibata-Modern-Classic cursor theme from nixpkgs' package,
# so the sway session and regreet share ONE identical recolored cursor (no
# vendored binaries, no stock/inconsistency drift).
#
# fill    = hot pink body   (was black)
# outline = gruvbox dark green (was white)
# Recolor against the same bibata-cursors 2.0.7 the vendored copy came from, so
# output is pixel-identical to the old home/cursor/Bibata-Modern-Classic tree.
{ pkgs }:

let
  fill = "#ff2b6d";
  outline = "#b8bb26";
in
pkgs.stdenv.mkDerivation {
  pname = "bibata-modern-classic-recolored";
  version = pkgs.lib.getVersion pkgs.bibata-cursors;

  nativeBuildInputs = [ pkgs.python3 ];

  dontUnpack = true;
  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out/share/icons
    cp -r ${pkgs.bibata-cursors}/share/icons/Bibata-Modern-Classic $out/share/icons/
    cp ${./recolor.py} $out/share/icons/recolor.py
    chmod -R u+w $out/share/icons
    ( cd $out/share/icons && python3 recolor.py '${fill}' '${outline}' )
    rm -f $out/share/icons/recolor.py
    runHook postInstall
  '';
}
