# Build a recolored Bibata-Modern-Classic cursor theme from nixpkgs' package,
# shared by the sway session and regreet.
#
# fill    = hot pink body
# outline = gruvbox dark green
{ pkgs, colors ? { accent = "#ff2b6d"; green = "#b8bb26"; } }:

let
  fill = colors.accent;
  outline = colors.green;
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
