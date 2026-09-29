# Token substitution — the ONE @TOKEN@ mechanism (waybar config, the quickshell
# menu, the set-res.sh template). Replaces @NAME@ placeholders from an attrset
# and FAILS EVALUATION if any @token@ survives in the output.
#
#   import ../../lib/tokens.nix "waybar/config.jsonc" {
#     BAR_ICON_SIZE = toString theme.bar.iconSize;
#   } (builtins.readFile ./waybar/config.jsonc)
#
# The guard matches any @word@, not just declared tokens, so a template that
# grew a placeholder without a value here also fails instead of shipping it as
# literal text (that was the old failure mode: a mistyped @SCALE_720@ became a
# literal GDK_SCALE value at runtime, silently).
#
# Templates must therefore not contain an innocent @word@; none do. CSS
# at-rules like @keyframes have no trailing @ and never match.
label: tokens: text:
let
  names = builtins.attrNames tokens;
  result = builtins.replaceStrings
    (map (name: "@${name}@") names)
    (map (name: tokens.${name}) names)
    text;
in
if builtins.match ".*@[A-Za-z0-9_]+@.*" result != null
then
  throw "lib/tokens.nix: unreplaced @token@ left in ${label} — add it to the token attrset or fix its spelling"
else result
