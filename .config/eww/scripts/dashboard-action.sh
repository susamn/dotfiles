#!/bin/bash
# Handles play and add actions for dashboard items

action="$1" # 'play' or 'add'
filter="$2" # 'track', 'playlist', or 'artist'
file="$3"

if [ "$action" = "play" ]; then
    mpc clear
fi

if [ "$filter" = "track" ]; then
    mpc add "$file"
elif [ "$filter" = "playlist" ]; then
    mpc load "$file"
elif [ "$filter" = "artist" ]; then
    mpc findadd artist "$file"
fi

if [ "$action" = "play" ]; then
    mpc play
fi
