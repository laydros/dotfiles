#!/bin/sh

sway output eDP-2 enable scale 1.4
sway output DP-3 enable
sway output eDP-2 position 2560,296

swaymsg workspace "4:"
swaymsg exec flatpak run org.mozilla.Thunderbird

swaymsg workspace "5:", move workspace to eDP-2
swaymsg exec flatpak run org.signal.Signal

swaymsg workspace "1:", move workspace to DP-3
swaymsg workspace "2:", move workspace to DP-3
swaymsg workspace "3:", move workspace to DP-3
swaymsg workspace "4:", move workspace to DP-3
swaymsg workspace "6:", move workspace to DP-3
swaymsg workspace "7:", move workspace to DP-3
swaymsg workspace "8:", move workspace to DP-3
swaymsg workspace "9:", move workspace to DP-3
swaymsg workspace "10:", move workspace to DP-3

