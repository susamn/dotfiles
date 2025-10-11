#!/bin/bash

# Default values
config_file=""
video_path=""

# Parse command-line arguments
while getopts "c:p:" opt; do
  case ${opt} in
    c )
      config_file=$OPTARG
      ;;
    p )
      video_path=$OPTARG
      ;;
    ? )
      echo "Invalid option: $OPTARG" 1>&2
      exit 1
      ;;
    : )
      echo "Invalid option: $OPTARG requires an argument" 1>&2
      exit 1
      ;;
  esac
done
shift $((OPTIND -1))

# Check if arguments are provided
if [ -z "${config_file}" ] || [ -z "${video_path}" ]; then
    echo "Usage: $0 -c <config_file> -p <video_path>"
    exit 1
fi

# Create the merged directory
merged_dir="${video_path}/merged"
mkdir -p "${merged_dir}"

# Read the config file and process each line
while IFS= read -r line; do
    # Parse the line
    id=$(echo "$line" | cut -d'=' -f1)
    times=$(echo "$line" | cut -d'=' -f2)
    start_time=$(echo "$times" | cut -d'-' -f1)
    end_time=$(echo "$times" | cut -d'-' -f2)

    # Find the video file
    video_file=$(find "${video_path}" -maxdepth 1 -name "${id}*" -print -quit)

    if [ -n "${video_file}" ]; then
        echo "Processing file: ${video_file}"
        output_file="${merged_dir}/${id%@}_part.mp4"
        
        # Cut the video
        ffmpeg -i "${video_file}" -ss "${start_time}" -to "${end_time}" -c:v libx264 -c:a aac -y "${output_file}" -loglevel quiet
        
        if [ $? -ne 0 ]; then
            echo "Error processing file: ${video_file}"
            exit 1
        fi

        echo "Done with file: ${video_file}"
    else
        echo "No file found starting with '${id}' in '${video_path}'. Skipping."
    fi
done < "${config_file}"

# Merge the video parts
echo "Merging video parts..."
cd "${merged_dir}" || exit

# Create a file list for ffmpeg
find . -name "*_part.mp4" -type f -printf "file '%p'\n" | sort -V > file_list.txt

# Merge the files
ffmpeg -f concat -safe 0 -i file_list.txt -c copy -y merged.mp4 -loglevel quiet

if [ $? -ne 0 ]; then
    echo "Error merging video parts."
    exit 1
fi

echo "Merging complete. Output file: ${merged_dir}/merged.mp4"

# Clean up the file list
rm file_list.txt
