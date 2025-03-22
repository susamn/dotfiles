#!/bin/bash

# Default values
DEST_DIR="$HOME"
USE_START_TIME=true

# Parse optional flags
while getopts "d:s" opt; do
  case $opt in
    d) DEST_DIR="$OPTARG" ;;  # Set custom destination directory
    s) USE_START_TIME=false ;;  # Skip asking for start time
    *) echo "Invalid option"; exit 1 ;;
  esac
done
shift $((OPTIND -1))

# Prompt for user input
echo "Enter the YouTube URL:"
read VIDEO_URL

if $USE_START_TIME; then
  echo "Enter the start time (HH:MM:SS):"
  read START_TIME
else
  START_TIME="00:00:00"
fi

echo "Enter the end time (HH:MM:SS):"
read END_TIME

echo "Enter the output file name (without extension):"
read FILE_NAME

# Set the output path
OUTPUT_PATH="$DEST_DIR/${FILE_NAME}.mp3"

# Display the command before executing
echo "Executing command:"
echo "yt-dlp -f bestaudio --extract-audio --audio-format mp3 \\
       --download-sections \"*${START_TIME}-${END_TIME}\" \\
       -o \"$OUTPUT_PATH\" \"$VIDEO_URL\""

# Run yt-dlp command
yt-dlp -f bestaudio --extract-audio --audio-format mp3 \
       --download-sections "*${START_TIME}-${END_TIME}" \
       -o "$OUTPUT_PATH" "$VIDEO_URL"

echo "Downloaded MP3 saved to: $OUTPUT_PATH"
