#!/bin/bash
src=$(pactl info | grep 'Default Source' | cut -d' ' -f3)
pactl list sources | awk -v src="$src" '/Name:/ {name=$2} /Description:/ {desc=$0} name==src && /Description:/ {gsub(/^[[:space:]]*Description: /, "", desc); print substr(desc, 1, 30); exit}'
