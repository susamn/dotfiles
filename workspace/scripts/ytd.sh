#!/bin/bash
set -euo pipefail

# Configuration variables
DEST_DIR="$HOME"
USE_START_TIME=true
MODE=""
SHOW_FORMAT=false
MULTIPART=false

show_help() {
  echo "Usage: $0 [-d destination_dir] [-s] [-a] [-v] [-f] [-m] [-h]"
  echo
  echo "Options:"
  echo "  -d destination_dir  Set custom destination directory (default: \$HOME)"
  echo "  -s                  Skip start time prompt (default: 00:00:00)"
  echo "  -a                  Download audio only (MP3)"
  echo "  -v                  Download video only"
  echo "  -f                  Show format selection menu"
  echo "  -m                  Enable multipart/concurrent downloads (faster)"
  echo "  -h                  Show this help message"
  echo
  echo "Examples:"
  echo "  $0 -a -d ~/Music    # Download audio to Music directory"
  echo "  $0 -v -f -m         # Fast video download with format selection"
}

validate_time() {
  local time=$1
  [[ "$time" == "inf" ]] && return 0
  [[ "$time" =~ ^([0-9]{1,2}:)?([0-9]{1,2}:)?[0-9]{1,2}$ ]] || [[ "$time" =~ ^[0-9]+$ ]]
}

while getopts "d:savfmh" opt; do
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
    m) MULTIPART=true ;;
    h) show_help; exit 0 ;;
    *) echo "Invalid option" >&2; show_help; exit 1 ;;
  esac
done
shift $((OPTIND - 1))

[ -z "$MODE" ] && { echo "Must specify -a or -v" >&2; show_help; exit 1; }

# Validate dependencies
command -v yt-dlp >/dev/null 2>&1 || { echo "yt-dlp required" >&2; exit 1; }
command -v ffmpeg >/dev/null 2>&1 || { echo "ffmpeg required for audio/video processing" >&2; exit 1; }

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
    read -rp "Start time [HH:MM:SS or seconds] (Enter for 0): " START_TIME
    START_TIME=${START_TIME:-0}
    validate_time "$START_TIME" && break
    echo "Invalid time format" >&2
  done
else
  START_TIME="0"
fi

while :; do
  read -rp "End time [HH:MM:SS, seconds, or 'inf' for end] (Enter for end): " END_TIME
  END_TIME=${END_TIME:-inf}
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
shopt -s nullglob
check_path="${output_template/%\%(ext\)s/*}"
# If check_path has no glob characters, nullglob won't filter it.
# We check if the file actually exists.
files=()
for f in $check_path; do
  [ -e "$f" ] && files+=("$f")
done
if [ ${#files[@]} -gt 0 ]; then
  read -rp "File exists. Overwrite? [y/N] " overwrite
  [[ "$overwrite" =~ ^[Yy] ]] || exit 0
fi
shopt -u nullglob

# Build command
declare -a cmd=(
  yt-dlp
  "${format_opts[@]}"
  --download-sections "*${START_TIME}-${END_TIME}"
  --force-overwrites
  --downloader-args "ffmpeg:-allowed_extensions ALL"
  -o "$output_template"
)

# Speed optimization: Use aria2c if available, otherwise check -m flag
if command -v aria2c >/dev/null 2>&1; then
  # aria2c provides multi-connection downloading (similar to IDM)
  cmd+=(--downloader aria2c --downloader-args "aria2c:-c -x 16 -s 16 -k 1M")
  # Also enable fragment concurrency for DASH/HLS streams
  cmd+=(-N 8)
elif $MULTIPART; then
  # Fallback to yt-dlp's built-in multi-threaded downloader
  cmd+=(-N 8)
fi

cmd+=(-- "$VIDEO_URL")

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
