import os
import json
import subprocess
import urllib.request
import urllib.parse
from pathlib import Path
import time

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

def fetch_lyrics(title, artist, album, duration=None):
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
                if data and 'plainLyrics' in data and data['plainLyrics']:
                    return data['plainLyrics']
    except urllib.error.HTTPError as e:
        pass
    except Exception as e:
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
                        if item.get('plainLyrics'):
                            return item['plainLyrics']
    except Exception as e:
        pass
        
    return None

def process_directory(directory):
    for root, dirs, files in os.walk(directory):
        for file in files:
            if file.lower().endswith(('.mp3', '.m4a', '.flac', '.ogg', '.wav')):
                filepath = os.path.join(root, file)
                name, _ = os.path.splitext(file)
                rel_path = os.path.relpath(root, '.')
                lyrics_dir = os.path.join('/home/susamn/Music/lyrics', rel_path)
                os.makedirs(lyrics_dir, exist_ok=True)
                txt_path = os.path.join(lyrics_dir, f"{name}.txt")
                
                if os.path.exists(txt_path):
                    print(f"Skipping {file} (lyrics already exist)")
                    continue
                    
                tags, duration = get_metadata(filepath)
                
                title = tags.get('title') or tags.get('TITLE')
                artist = tags.get('artist') or tags.get('ARTIST') or tags.get('album_artist') or tags.get('ARTISTS')
                album = tags.get('album') or tags.get('ALBUM')
                
                if not title:
                    print(f"Skipping {file} (no title tag)")
                    continue
                    
                print(f"Fetching lyrics for: {title} by {artist}")
                
                lyrics = fetch_lyrics(title, artist, album, duration)
                if lyrics:
                    with open(txt_path, 'w', encoding='utf-8') as f:
                        f.write(lyrics)
                    print(f"Saved lyrics for {file}")
                else:
                    print(f"No lyrics found for {file}")
                    
                time.sleep(1) # Be nice to the API

if __name__ == '__main__':
    import sys
    if len(sys.argv) > 1:
        for d in sys.argv[1:]:
            process_directory(d)
    else:
        process_directory('.')
