#!/usr/bin/env sh
# Toggle the bluejay bluetooth manager: $mod+b or the waybar bluetooth icon.
# Bluejay is native Wayland (app_id io.github.ebonjaeger.bluejay); manage it via
# sway IPC instead of process names (the nixpkgs wrapper renames the ELF to
# .bluejay-wrapped, so comm/argv0 matching is fragile).
if swaymsg -t get_tree | grep -qE '"app_id": ?"io\.github\.ebonjaeger\.bluejay"'; then
  swaymsg '[app_id="(?i)io.github.ebonjaeger.bluejay"]' kill >/dev/null
else
  bluejay >/dev/null 2>&1 &
fi