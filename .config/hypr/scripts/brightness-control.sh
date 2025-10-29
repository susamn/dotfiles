#!/bin/bash

# Get the action (up or down)
action=$1

# Adjust brightness
if [ "$action" == "up" ]; then
    brightnessctl -e4 -n2 set 5%+
elif [ "$action" == "down" ]; then
    brightnessctl -e4 -n2 set 5%-
fi

# Get current brightness percentage
current=$(brightnessctl get)
max=$(brightnessctl max)
percentage=$((current * 100 / max))

# Send notification to swaync
notify-send -h string:x-canonical-private-synchronous:brightness \
    -h int:value:$percentage \
    -u low \
    "Brightness" "Level: ${percentage}%"
