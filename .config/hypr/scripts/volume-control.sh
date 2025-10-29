#!/bin/bash

# Get the action (up, down, or mute)
action=$1

# Adjust volume
if [ "$action" == "up" ]; then
    wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+
elif [ "$action" == "down" ]; then
    wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-
elif [ "$action" == "mute" ]; then
    wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
fi

# Get current volume and mute status
volume=$(wpctl get-volume @DEFAULT_AUDIO_SINK@)
percentage=$(echo $volume | awk '{print int($2 * 100)}')
muted=$(echo $volume | grep -o "MUTED")

# Send notification to swaync
if [ "$muted" == "MUTED" ]; then
    notify-send -h string:x-canonical-private-synchronous:volume \
        -h int:value:0 \
        -u low \
        "Volume" "Muted"
else
    notify-send -h string:x-canonical-private-synchronous:volume \
        -h int:value:$percentage \
        -u low \
        "Volume" "Level: ${percentage}%"
fi
