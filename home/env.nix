# Session environment variables. Kept separate from the rest of home/ because
# every consumer here must be set BEFORE the session starts (sway inherits
# these; apps launched by sway inherit them from sway).
{ ... }:

let
  theme = import ../machine/theme.nix;
in
{
  home.sessionVariables = {
    XCURSOR_SIZE = toString theme.display.cursor.env;
    XCURSOR_THEME = theme.cursorTheme;
    # SDL's hidapi driver for Switch pads opens the controller's hidraw node and
    # runs its own handshake on it, which fights hid-nintendo's. The kernel then
    # logs "timeout waiting for input report" / "joycon_enforce_subcmd_rate:
    # exceeded max attempts", event20 stops delivering events to EVERYONE (sway,
    # the quickshell evdev patch, D-pad volume/brightness), and only a BT
    # reconnect clears it — with OBS open the pad looks dead machine-wide.
    # Session-wide on purpose: any SDL app can wedge it (OBS's input-overlay
    # gamepad hook, Moonlight). Disabling just the Switch driver keeps hidapi for
    # other pads; the evdev path still gives buttons/sticks and FF rumble via
    # hid-nintendo. Must be set before SDL_Init, hence session-level, and OBS
    # needs a restart to pick it up.
    SDL_JOYSTICK_HIDAPI_SWITCH = "0";
    # Second SDL problem: the evdev mapping SDL auto-generates for this pad is
    # scrambled — its button indices don't match the order the kernel enumerates
    # them in, so A/B and X/Y come out swapped and shoulders/triggers/-/+/guide/
    # sticks are all shifted, and the capture button is dropped entirely. Read
    # live off SDL: a:b1,b:b0,x:b3,y:b2,back:b8,start:b9,guide:b12,
    # leftshoulder:b4,rightshoulder:b5,leftstick:b10,rightstick:b11,
    # lefttrigger:b6,righttrigger:b7 (no misc1) — i.e. everything the
    # input-overlay preset expects lights the wrong thing.
    # Pin it ourselves. Indices are the pad's ascending BTN_ codes from
    # /sys/class/input/event20/device/capabilities/key:
    #   0=SOUTH(B) 1=EAST(A) 2=NORTH(X) 3=WEST(Y) 4=Z(capture) 5=TL(L) 6=TR(R)
    #   7=TL2(ZL) 8=TR2(ZR) 9=SELECT(-) 10=START(+) 11=MODE(home)
    #   12=THUMBL(L3) 13=THUMBR(R3)
    # misc1:b4 finally gives the capture button a mapping (evdev reports it as
    # BTN_Z, which SDL's generator ignores). Verified against SDL::
    # SDL_AddGamepadMapping() accepts this string and
    # SDL_GetGamepadMappingForGUID() then returns it. GUID is this pad's
    # (BT-derived) GUID, so other controllers are unaffected.
    SDL_GAMECONTROLLERCONFIG = "0500d71f7e0500000920000000800000,Nintendo Switch Pro Controller,a:b0,b:b1,x:b3,y:b2,back:b9,start:b10,guide:b11,leftshoulder:b5,rightshoulder:b6,leftstick:b12,rightstick:b13,lefttrigger:b7,righttrigger:b8,misc1:b4,dpup:h0.1,dpdown:h0.4,dpleft:h0.8,dpright:h0.2,leftx:a0,lefty:a1,rightx:a2,righty:a3,platform:Linux,";
  };
}
