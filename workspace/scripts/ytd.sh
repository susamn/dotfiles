#!/bin/bash

DEST_DIR="$HOME"
USE_START_TIME=true
MODE=""

# Function to display help
show_help() {
  echo "Usage: $0 [-d destination_dir] [-s] [-a] [-v] [-h]"
  echo
  echo "Options:"
  echo "  -d destination_dir  Set the custom destination directory (default: $HOME)"
  echo "  -s                  Skip asking for the start time (default: ask for start time)"
  echo "  -a                  Download audio only (MP3)"
  echo "  -v                  Download video only (MP4)"
  echo "  -h                  Display this help message"
  echo
  echo "Example Usage:"
  echo "  $0 -a -d /path/to/destination 'https://youtube.com/video_url'  # Download audio (MP3)"
  echo "  $0 -v -d /path/to/destination 'https://youtube.com/video_url'  # Download video (MP4)"
}

while getopts "d:sv:ah" opt; do
  case $opt in
    d) DEST_DIR="$OPTARG" ;;  # Set custom destination directory
    s) USE_START_TIME=false ;;  # Skip asking for start time
    v) MODE="video" ;;  # Set mode to video
    a) MODE="audio" ;;  # Set mode to audio
    h) show_help; exit 0 ;;  # Show help and exit
    *) echo "Invalid option"; show_help; exit 1 ;;
  esac
done
shift $((OPTIND -1))

if [ -z "$MODE" ]; then
  echo "Error: You must specify either -a for audio or -v for video."
  show_help
  exit 1
fi

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

if [ "$MODE" == "audio" ]; then
  OUTPUT_PATH="$DEST_DIR/${FILE_NAME}.mp3"
  FORMAT_OPTIONS="--extract-audio --audio-format mp3"  # Only extract audio
else
  OUTPUT_PATH="$DEST_DIR/${FILE_NAME}.mp4"
  FORMAT_OPTIONS="-f bestvideo+bestaudio"  # Only download video and audio as video
fi

echo "Executing command:"
echo "yt-dlp $FORMAT_OPTIONS --download-sections \"*${START_TIME}-${END_TIME}\" \\
       -o \"$OUTPUT_PATH\" \"$VIDEO_URL\""

yt-dlp $FORMAT_OPTIONS --download-sections "*${START_TIME}-${END_TIME}" \
       -o "$OUTPUT_PATH" "$VIDEO_URL"

if [ "$MODE" == "audio" ]; then
  echo "Downloaded MP3 saved to: $OUTPUT_PATH"
else
  echo "Downloaded video saved to: $OUTPUT_PATH"
fi

