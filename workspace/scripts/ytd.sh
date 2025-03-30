#!/bin/bash
set -euo pipefail

# Configuration variables
DEST_DIR="$HOME"
USE_START_TIME=true
MODE=""
SHOW_FORMAT=false

show_help() {
  echo "Usage: $0 [-d destination_dir] [-s] [-a] [-v] [-f] [-h]"
  echo
  echo "Options:"
  echo "  -d destination_dir  Set custom destination directory (default: \$HOME)"
  echo "  -s                  Skip start time prompt (default: 00:00:00)"
  echo "  -a                  Download audio only (MP3)"
  echo "  -v                  Download video only"
  echo "  -f                  Show format selection menu"
  echo "  -h                  Show this help message"
  echo
  echo "Examples:"
  echo "  $0 -a -d ~/Music    # Download audio to Music directory"
  echo "  $0 -v -f            # Video download with format selection"
}

validate_time() {
  local time=$1
  [[ "$time" =~ ^([0-9]{2}):([0-9]{2}):([0-9]{2})$ ]] || return 1
  local h=$((10#${BASH_REMATCH[1]}))
  local m=$((10#${BASH_REMATCH[2]}))
  local s=$((10#${BASH_REMATCH[3]}))
  
  (( h >= 0 && h <= 23 )) || return 1
  (( m >= 0 && m <= 59 )) || return 1
  (( s >= 0 && s <= 59 )) || return 1
}

while getopts "d:savfh" opt; do
  case $opt in
    d) DEST_DIR="$OPTARG" ;;
    s) USE_START_TIME=false ;;
    a)
      [ -n "$MODE" ] && { echo "Cannot use -a and -v together" >&2; exit 1; }
      MODE="audio"
      ;;
    v)
      [ -n "$MODE" ] && { echo "Cannot use -a and -v together" >&2; exit 1; }
      MODE="video"
      ;;
    f) SHOW_FORMAT=true ;;
    h) show_help; exit 0 ;;
    *) echo "Invalid option" >&2; show_help; exit 1 ;;
  esac
done
shift $((OPTIND - 1))

[ -z "$MODE" ] && { echo "Must specify -a or -v" >&2; show_help; exit 1; }

# Validate dependencies
command -v yt-dlp >/dev/null 2>&1 || { echo "yt-dlp required" >&2; exit 1; }

# Validate destination directory
mkdir -p "$DEST_DIR" 2>/dev/null || true
[ -d "$DEST_DIR" ] || { echo "Invalid destination directory" >&2; exit 1; }
[ -w "$DEST_DIR" ] || { echo "Destination not writable" >&2; exit 1; }

# Get and validate URL
read -rp "YouTube URL: " VIDEO_URL
[[ "$VIDEO_URL" =~ ^https?://(www\.)?(youtube\.com|youtu\.be) ]] || { echo "Invalid URL" >&2; exit 1; }

# Format selection
declare -a format_opts
if $SHOW_FORMAT; then
  yt-dlp -F "$VIDEO_URL" || exit $?
  read -rp "Format number: " fmt
  [[ "$fmt" =~ ^[0-9]+$ ]] || { echo "Invalid format" >&2; exit 1; }
  format_opts=(-f "$fmt")
else
  case "$MODE" in
    audio) format_opts=(--extract-audio --audio-format mp3) ;;
    video) format_opts=(-f "bestvideo[ext=mp4]+bestaudio[ext=m4a]/best[ext=mp4]/best") ;;
  esac
fi

# Time selection
if $USE_START_TIME; then
  while :; do
    read -rp "Start time [HH:MM:SS] (Enter for 00:00:00): " START_TIME
    START_TIME=${START_TIME:-00:00:00}
    validate_time "$START_TIME" && break
    echo "Invalid time format" >&2
  done
else
  START_TIME="00:00:00"
fi

while :; do
  read -rp "End time [HH:MM:SS]: " END_TIME
  validate_time "$END_TIME" && break
  echo "Invalid time format" >&2
done

# Filename handling
while :; do
  read -rp "Output filename (without extension): " FILE_NAME
  [ -n "$FILE_NAME" ] && break
  echo "Filename required" >&2
done

# Output path construction
declare output_template
if $SHOW_FORMAT || [ "$MODE" = "video" ]; then
  output_template="$DEST_DIR/${FILE_NAME}.%(ext)s"
else
  output_template="$DEST_DIR/${FILE_NAME}.mp3"
fi

# Existing file check
if [[ "$output_template" != *%* ]]; then  # Only check if static filename
  if [ -e "${output_template%%\%*}"* ]; then
    read -rp "File exists. Overwrite? [y/N] " overwrite
    [[ "${overwrite,,}" =~ ^y ]] || exit 0
  fi
fi

# Build command
declare -a cmd=(
  yt-dlp
  "${format_opts[@]}"
  --download-sections "*${START_TIME}-${END_TIME}"
  --force-overwrites
  -o "$output_template"
  -- "$VIDEO_URL"
)

# Execute download
echo "Downloading..."
"${cmd[@]}" || { echo "Download failed" >&2; exit 1; }

# Verify output
shopt -s nullglob
case "$MODE" in
  audio) outputs=("$DEST_DIR/${FILE_NAME}.mp3") ;;
  video) outputs=("$DEST_DIR/${FILE_NAME}".*) ;;
esac

[ ${#outputs[@]} -gt 0 ] || { echo "No output file created" >&2; exit 1; }

echo "Successfully downloaded:"
printf " - %s\n" "${outputs[@]}"
