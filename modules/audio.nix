{ ... }:

{
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;   # replaces PulseAudio entirely
    # jack.enable = false;  # enable if you ever need JACK apps
  };
}
