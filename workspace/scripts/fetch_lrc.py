import os
import json
import subprocess
import urllib.request
import urllib.parse
from pathlib import Path
import time
import concurrent.futures

def get_metadata(filepath):
    try:
        cmd = [
            "ffprobe", "-v", "quiet", "-print_format", "json",
            "-show_format", filepath
        ]
        result = subprocess.run(cmd, capture_output=True, text=True)
        if result.returncode == 0:
            data = json.loads(result.stdout)
            format_info = data.get("format", {})
            tags = format_info.get("tags", {})
            duration = format_info.get("duration")
            return tags, duration
    except Exception as e:
        print(f"Error reading {filepath}: {e}")
    return {}, None

def fetch_lrc(title, artist, album, duration=None):
    if not title:
        return None
    
    base_url = "https://lrclib.net/api/get"
    params = {}
    params['track_name'] = title
    if artist:
        params['artist_name'] = artist
    if album:
        params['album_name'] = album
    if duration:
        params['duration'] = str(int(float(duration)))
        
    query_string = urllib.parse.urlencode(params)
    url = f"{base_url}?{query_string}"
    
    req = urllib.request.Request(url, headers={'User-Agent': 'MusicTagger/1.0 (user@example.com)'})
    try:
        with urllib.request.urlopen(req, timeout=5) as response:
            if response.status == 200:
                data = json.loads(response.read().decode('utf-8'))
                if data and 'syncedLyrics' in data and data['syncedLyrics']:
                    return data['syncedLyrics']
    except Exception:
        pass
        
    # Fallback to search API if exact match fails
    search_query = title
    if artist:
        search_query += f" {artist}"
        
    search_url = f"https://lrclib.net/api/search?{urllib.parse.urlencode({'q': search_query})}"
    req2 = urllib.request.Request(search_url, headers={'User-Agent': 'MusicTagger/1.0 (user@example.com)'})
    try:
        with urllib.request.urlopen(req2, timeout=5) as response:
            if response.status == 200:
                data = json.loads(response.read().decode('utf-8'))
                if data and len(data) > 0:
                    for item in data:
                        if item.get('syncedLyrics'):
                            return item['syncedLyrics']
    except Exception:
        pass
        
    return None

def process_file(filepath, root_dir, base_music_dir):
    file = os.path.basename(filepath)
    name, _ = os.path.splitext(file)
    rel_path = os.path.relpath(os.path.dirname(filepath), base_music_dir)
    lyrics_dir = os.path.join('/home/susamn/Music/music-metadata/lyrics', rel_path)
    os.makedirs(lyrics_dir, exist_ok=True)
    lrc_path = os.path.join(lyrics_dir, f"{name}.lrc")
    
    if os.path.exists(lrc_path):
        print(f"Skipping {file} (LRC already exists)")
        return
        
    tags, duration = get_metadata(filepath)
    
    title = tags.get('title') or tags.get('TITLE')
    artist = tags.get('artist') or tags.get('ARTIST') or tags.get('album_artist') or tags.get('ARTISTS')
    album = tags.get('album') or tags.get('ALBUM')
    
    if not title:
        print(f"Skipping {file} (no title tag)")
        return
        
    print(f"Fetching LRC for: {title} by {artist}")
    
    lrc = fetch_lrc(title, artist, album, duration)
    if lrc:
        with open(lrc_path, 'w', encoding='utf-8') as f:
            f.write(lrc)
        print(f"Saved LRC for {file}")
    else:
        print(f"No LRC found for {file}")
        
    time.sleep(1) # Be nice to the API

def process_directory(directory):
    base_music_dir = os.path.abspath(directory)
    files_to_process = []
    for root, dirs, files in os.walk(base_music_dir):
        for file in files:
            if file.lower().endswith(('.mp3', '.m4a', '.flac', '.ogg', '.wav')):
                filepath = os.path.join(root, file)
                files_to_process.append(filepath)
    
    print(f"Found {len(files_to_process)} music files. Processing with 50 agents...")
    with concurrent.futures.ThreadPoolExecutor(max_workers=50) as executor:
        futures = [executor.submit(process_file, f, os.path.dirname(f), base_music_dir) for f in files_to_process]
        for future in concurrent.futures.as_completed(futures):
            try:
                future.result()
            except Exception as e:
                print(f"Error processing file: {e}")

if __name__ == '__main__':
    music_dir = '/home/susamn/Music/susamn-music-collection'
    process_directory(music_dir)
