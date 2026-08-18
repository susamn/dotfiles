#!/bin/bash
# Streams MPD's current playback state, track (artist/title), and album
# art path for the mpd player widget's `mpd_status` deflisten variable.
#
# Album art extraction mirrors ~/.config/conky/get-mpd-info.sh's own
# ffmpeg+convert technique exactly, but with its own cache file
# (ALBUMART_PATH/CACHE_FILE below) rather than reusing that script's
# /tmp/conky-albumart.jpg -- this widget shouldn't silently break if
# that conky instance ever stops running.
CACHE_FILE="/tmp/eww-mpd-player-track.txt"
ALBUMART_PATH="/tmp/eww-mpd-albumart.jpg"
# eww's (image) widget hard-errors ("Failed to open file """) on an
# empty :path rather than rendering a blank/placeholder -- so this is
# always emitted instead of "" when there's no real art (nothing
# playing, extraction failed, or the track has no embedded art), never
# left for eww.yuck to handle as a missing-value case.
PLACEHOLDER_PATH="/tmp/eww-mpd-albumart-placeholder.png"
MUSIC_DIR=$(grep -E "^music_directory" ~/.config/mpd/mpd.conf 2>/dev/null | sed 's/music_directory[[:space:]]*"\(.*\)"/\1/' | sed "s|~|$HOME|")
[ -z "$MUSIC_DIR" ] && MUSIC_DIR="$HOME/Music"
[ -f "$PLACEHOLDER_PATH" ] || convert -size 120x120 xc:'#2a2a2a' "$PLACEHOLDER_PATH" 2>/dev/null

prev=""
while true; do
    state=$(mpc status 2>/dev/null | grep -oP '\[\K[^\]]+' || echo "stop")
    artist=$(mpc current -f '%artist%' 2>/dev/null)
    title=$(mpc current -f '%title%' 2>/dev/null)
    file=$(mpc current -f '%file%' 2>/dev/null)
    year=$(mpc current -f '%date%' 2>/dev/null)
    composer=$(mpc current -f '%composer%' 2>/dev/null)
    queue_length=$(mpc playlist 2>/dev/null | wc -l)
    progress=$(mpc status 2>/dev/null | grep -oP '\(\K[0-9]+(?=%\))' || echo "0")
    time_str=$(mpc status 2>/dev/null | grep -oP '\d+:\d+/\d+:\d+' | sed 's|/| / |' || echo "0:00 / 0:00")

    if [ -n "$file" ]; then
        # Only re-extract when the track actually changed -- ffmpeg+convert
        # on every 1s tick would be wasteful and pointless (the art
        # can't have changed if the track hasn't).
        if [ ! -f "$CACHE_FILE" ] || [ "$(cat "$CACHE_FILE" 2>/dev/null)" != "$file" ]; then
            rm -f "$ALBUMART_PATH"
            full_path="$MUSIC_DIR/$file"
            if [ -f "$full_path" ]; then
                ffmpeg -i "$full_path" -an -c:v copy "$ALBUMART_PATH" -y 2>/dev/null
                if [ -s "$ALBUMART_PATH" ]; then
                    convert "$ALBUMART_PATH" -resize 120x120! "$ALBUMART_PATH" 2>/dev/null
                fi
            fi
            echo "$file" > "$CACHE_FILE"
        fi
    else
        rm -f "$ALBUMART_PATH" "$CACHE_FILE"
    fi

    albumart="$PLACEHOLDER_PATH"
    [ -s "$ALBUMART_PATH" ] && albumart="$ALBUMART_PATH"

    line="${state}|${artist}|${title}|${file}|${year}|${composer}|${queue_length}|${progress}|${time_str}"
    if [ "$line" != "$prev" ]; then
        jq -cn --arg state "$state" --arg artist "$artist" --arg title "$title" --arg albumart "$albumart" --arg year "$year" --arg composer "$composer" --arg queue "$queue_length" --arg progress "$progress" --arg time "$time_str" \
            '{state: $state, artist: $artist, title: $title, albumart: $albumart, year: $year, composer: $composer, queue_length: $queue, progress: $progress, time: $time}'
        prev="$line"
    fi

    sleep 1
done
