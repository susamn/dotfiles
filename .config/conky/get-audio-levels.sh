#!/bin/bash
# Output volume
pactl get-sink-volume @DEFAULT_SINK@ | awk '{print $5}' | tr -d '%'
