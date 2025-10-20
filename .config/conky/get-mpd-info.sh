#!/bin/bash

# Get current song info
current=$(mpc current -f '%artist% - %title%' 2>/dev/null)
album=$(mpc current -f '%album%' 2>/dev/null)
status=$(mpc status 2>/dev/null | grep -oP '\[\K[^\]]+' || echo "Stopped")
time=$(mpc status 2>/dev/null | grep -oP '\d+:\d+/\d+:\d+' || echo "")
file_path=$(mpc current -f '%file%' 2>/dev/null)
playlist_position=$(mpc status 2>/dev/null | grep -oP '#\K\d+/\d+' || echo "")

# Album art extraction
ALBUMART_PATH="/tmp/conky-albumart.jpg"
CACHE_FILE="/tmp/conky-current-track"

# Extract album art from embedded image
if [ -n "$file_path" ]; then
    # Get MPD music directory from config
    mpd_music_dir=$(grep -E "^music_directory" ~/.config/mpd/mpd.conf 2>/dev/null | sed 's/music_directory[[:space:]]*"\(.*\)"/\1/' | sed "s|~|$HOME|")

    # Fallback to common music directory if not found
    [ -z "$mpd_music_dir" ] && mpd_music_dir="$HOME/Music"

    full_path="$mpd_music_dir/$file_path"

    # Check if this is a new track
    if [ ! -f "$CACHE_FILE" ] || [ "$(cat "$CACHE_FILE" 2>/dev/null)" != "$file_path" ]; then
        # Remove old album art to force Conky to reload
        rm -f "$ALBUMART_PATH"

        # Extract album art using ffmpeg
        if [ -f "$full_path" ]; then
            ffmpeg -i "$full_path" -an -c:v copy "$ALBUMART_PATH" -y 2>/dev/null

            # Resize the image to exact dimensions to prevent panel displacement
            if [ -f "$ALBUMART_PATH" ] && command -v convert &> /dev/null; then
                convert "$ALBUMART_PATH" -resize 240x240! "$ALBUMART_PATH" 2>/dev/null
            fi

            # If ffmpeg didn't extract anything, create a placeholder
            if [ ! -s "$ALBUMART_PATH" ]; then
                # Remove empty file and create a simple placeholder using ImageMagick if available
                rm -f "$ALBUMART_PATH"
                if command -v convert &> /dev/null; then
                    convert -size 240x240 xc:black -gravity center -fill white -pointsize 20 -annotate +0+0 "No\nAlbum Art" "$ALBUMART_PATH" 2>/dev/null
                fi
            fi
        fi

        # Cache current track
        echo "$file_path" > "$CACHE_FILE"
    fi
else
    # No music playing, remove cache and album art
    rm -f "$CACHE_FILE" "$ALBUMART_PATH"
fi

# Display track info with fixed line count
if [ -n "$current" ]; then
    # Truncate long text to prevent wrapping
    current_truncated=$(echo "$current" | cut -c1-40)
    album_truncated=$(echo "$album" | cut -c1-35)

    echo "$current_truncated"
    if [ -n "$album" ]; then
        echo "Album: $album_truncated"
    else
        echo ""
    fi
    echo "$status $time"
    if [ -n "$playlist_position" ]; then
        echo "Track: $playlist_position"
    else
        echo ""
    fi
else
    echo "No music playing"
    echo ""
    echo ""
    echo ""
fi
