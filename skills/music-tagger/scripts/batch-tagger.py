import os
import subprocess
import json
import sys

def update_tags(base_path, mapping_file):
    try:
        with open(mapping_file, 'r') as f:
            files_to_tags = json.load(f)
    except Exception as e:
        print(f"Error loading mapping file: {e}")
        return

    for filename, tags in files_to_tags.items():
        file_path = os.path.join(base_path, filename)
        if not os.path.exists(file_path):
            print(f"File not found: {file_path}")
            continue
        
        temp_path = os.path.join(base_path, "temp_" + filename)
        
        cmd = ["ffmpeg", "-y", "-i", file_path, "-c", "copy"]
        
        if isinstance(tags, str):
            cmd.extend(["-metadata", f"artist={tags}"])
        elif isinstance(tags, dict):
            for key, value in tags.items():
                cmd.extend(["-metadata", f"{key}={value}"])
        
        cmd.append(temp_path)
        
        print(f"Updating {filename}...")
        result = subprocess.run(cmd, capture_output=True, text=True)
        
        if result.returncode == 0:
            os.replace(temp_path, file_path)
        else:
            print(f"Error updating {filename}: {result.stderr}")
            if os.path.exists(temp_path):
                os.remove(temp_path)

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: python3 batch-tagger.py <directory> <mapping_json>")
        sys.exit(1)
    update_tags(sys.argv[1], sys.argv[2])
