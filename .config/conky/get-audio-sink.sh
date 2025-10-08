#!/bin/bash
sink=$(pactl info | grep 'Default Sink' | cut -d' ' -f3)
pactl list sinks | awk -v sink="$sink" '/Name:/ {name=$2} /Description:/ {desc=$0} name==sink && /Description:/ {gsub(/^[[:space:]]*Description: /, "", desc); print substr(desc, 1, 30); exit}'
