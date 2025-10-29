#!/bin/bash

# Handle laptop lid events
# When lid closes, distribute eDP-1 workspaces and disable it
# When lid opens, re-enable eDP-1

if grep -q closed /proc/acpi/button/lid/*/state; then
    # Lid is closed
    # Move all workspaces from eDP-1 to DP-1
    for i in {1..10}; do
        hyprctl dispatch moveworkspacetomonitor $i DP-1 2>/dev/null
    done

    # Disable laptop screen
    hyprctl keyword monitor "eDP-1,disable"
else
    # Lid is open - re-enable laptop screen
    hyprctl keyword monitor "eDP-1,3072x1920@60,0x0,2"
fi
