
import argparse
import os
import re
import subprocess
import sys

# Supported video file extensions
SUPPORTED_FORMATS = ('.mp4', '.wmv', '.avi', '.ts', '.flv', '.mkv', '.mov', '.m4v', '.webm', '.mpg', '.mpeg')

def create_video_map(input_dir):
    """Recursively scans the input directory and creates a map of video files."""
    video_map = {}
    for root, _, files in os.walk(input_dir):
        for file in files:
            # Check if file has @ and is a video file
            if '@' in file and file.lower().endswith(SUPPORTED_FORMATS):
                video_id = file.split('@')[0] + '@'
                # Warn if duplicate ID found
                if video_id in video_map:
                    print(f"Warning: Multiple files found for ID '{video_id}'. Using: {os.path.join(root, file)}", file=sys.stderr)
                video_map[video_id] = os.path.join(root, file)
    return video_map

def validate_time_format(time_str):
    """Validates time format (HH:MM:SS or MM:SS)."""
    # Pattern: HH:MM:SS.mmm or HH:MM:SS or MM:SS
    pattern = r'^(?:\d{1,2}:)?\d{1,2}:\d{1,2}(?:\.\d{1,3})?$'
    if not re.match(pattern, time_str):
        return False

    # Additional validation: check if seconds/minutes are valid (0-59)
    parts = time_str.split(':')
    try:
        if len(parts) == 3:  # HH:MM:SS
            hours, minutes, seconds = parts
            seconds_parts = seconds.split('.')
            if int(minutes) >= 60 or int(seconds_parts[0]) >= 60:
                return False
        elif len(parts) == 2:  # MM:SS
            minutes, seconds = parts
            seconds_parts = seconds.split('.')
            if int(seconds_parts[0]) >= 60:
                return False
    except ValueError:
        return False

    return True

def check_ffmpeg_installed():
    """Checks if ffmpeg is installed and available."""
    try:
        result = subprocess.run(['ffmpeg', '-version'],
                              capture_output=True,
                              text=True,
                              timeout=5)
        return result.returncode == 0
    except (FileNotFoundError, subprocess.TimeoutExpired, PermissionError):
        return False

def main():
    parser = argparse.ArgumentParser(description="Cut and merge video files based on a config.")
    parser.add_argument("-c", "--config", required=True, help="Path to the configuration file.")
    parser.add_argument("-p", "--path", required=True, help="Path to the directory containing video files.")
    parser.add_argument("-o", "--output", required=True, help="Path to the output directory.")
    args = parser.parse_args()

    # Check if ffmpeg is installed
    if not check_ffmpeg_installed():
        print("Error: ffmpeg is not installed or not available in PATH.", file=sys.stderr)
        print("Please install ffmpeg to use this script.", file=sys.stderr)
        sys.exit(1)

    # Validate input directory exists
    if not os.path.isdir(args.path):
        print(f"Error: Input directory does not exist: {args.path}", file=sys.stderr)
        sys.exit(1)

    # Validate config file exists
    if not os.path.isfile(args.config):
        print(f"Error: Config file does not exist: {args.config}", file=sys.stderr)
        sys.exit(1)

    # Create the output directory
    try:
        merged_dir = os.path.join(args.output, "merged")
        os.makedirs(merged_dir, exist_ok=True)
    except (PermissionError, OSError) as e:
        print(f"Error: Cannot create output directory: {e}", file=sys.stderr)
        sys.exit(1)

    print("Scanning for video files...")
    video_map = create_video_map(args.path)
    print(f"Found {len(video_map)} potential video files.")

    cut_files = []

    try:
        with open(args.config, 'r') as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith('#'):  # Skip empty lines and comments
                    continue

                try:
                    video_id, times = line.split('=', 1)
                    video_id = video_id.strip()  # Remove whitespace from video ID
                    start_time, end_time = times.split('-', 1)
                    start_time = start_time.strip()
                    end_time = end_time.strip()
                except ValueError:
                    print(f"Skipping malformed line in config: {line}")
                    continue

                # Validate time formats
                if not validate_time_format(start_time) or not validate_time_format(end_time):
                    print(f"Skipping line with invalid time format: {line} (times must be HH:MM:SS or MM:SS with valid values)")
                    continue

                if video_id in video_map:
                    video_file = video_map[video_id]

                    # Check if video file still exists and is readable
                    if not os.path.isfile(video_file):
                        print(f"Warning: Video file no longer exists: {video_file}. Skipping.", file=sys.stderr)
                        continue

                    if not os.access(video_file, os.R_OK):
                        print(f"Warning: Cannot read video file: {video_file}. Skipping.", file=sys.stderr)
                        continue

                    print(f"Processing file: {video_file}")

                    part_num = video_id.replace('@', '')
                    output_file = os.path.join(merged_dir, f"{part_num}_part.mp4")
                    cut_files.append(output_file)

                    command = [
                        'ffmpeg',
                        '-i', video_file,
                        '-ss', start_time,
                        '-to', end_time,
                        '-c:v', 'libx264',
                        '-c:a', 'aac',
                        '-y',
                        output_file,
                        '-loglevel', 'quiet'
                    ]

                    try:
                        result = subprocess.run(command, capture_output=True, text=True, timeout=600)

                        if result.returncode != 0:
                            print(f"Error processing file: {video_file}", file=sys.stderr)
                            print(f"ffmpeg stderr:\n{result.stderr}", file=sys.stderr)
                            sys.exit(1)

                        print(f"Done with file: {video_file}")
                    except subprocess.TimeoutExpired:
                        print(f"Error: Processing timed out for file: {video_file}", file=sys.stderr)
                        sys.exit(1)
                    except Exception as e:
                        print(f"Error: Unexpected error processing file {video_file}: {e}", file=sys.stderr)
                        sys.exit(1)
                else:
                    print(f"No file found for ID '{video_id}' in '{args.path}'. Skipping.")

    except FileNotFoundError:
        print(f"Error: Config file not found at {args.config}", file=sys.stderr)
        sys.exit(1)
    except (PermissionError, OSError) as e:
        print(f"Error: Cannot read config file: {e}", file=sys.stderr)
        sys.exit(1)

    if not cut_files:
        print("No video parts were created. Exiting.")
        sys.exit(0)

    print("Merging video parts...")

    # Create a file list for ffmpeg using absolute paths
    file_list_path = os.path.join(merged_dir, "file_list.txt")

    try:
        with open(file_list_path, 'w') as f:
            for file_path in cut_files:
                # ffmpeg's concat demuxer requires paths to be quoted if they contain special characters
                f.write(f"file '{file_path}'\n")
    except (PermissionError, OSError) as e:
        print(f"Error: Cannot create file list: {e}", file=sys.stderr)
        sys.exit(1)

    final_output_file = os.path.join(merged_dir, "merged.mp4")
    merge_command = [
        'ffmpeg',
        '-f', 'concat',
        '-safe', '0',
        '-i', file_list_path,
        '-c', 'copy',
        '-y',
        final_output_file,
        '-loglevel', 'quiet'
    ]

    try:
        result = subprocess.run(merge_command, capture_output=True, text=True, timeout=600)

        if result.returncode != 0:
            print("Error merging video parts.", file=sys.stderr)
            print(f"ffmpeg stderr:\n{result.stderr}", file=sys.stderr)
            sys.exit(1)

        print(f"Merging complete. Output file: {final_output_file}")
    except subprocess.TimeoutExpired:
        print("Error: Merging timed out.", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"Error: Unexpected error during merge: {e}", file=sys.stderr)
        sys.exit(1)

    # Clean up the file list
    try:
        os.remove(file_list_path)
    except OSError:
        pass  # Ignore cleanup errors

if __name__ == "__main__":
    main()
