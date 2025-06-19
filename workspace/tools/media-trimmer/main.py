import os
import subprocess
import shutil
from pathlib import Path
from typing import Optional, List
import tempfile
import uuid
from datetime import datetime
import asyncio
import json

from fastapi import FastAPI, File, UploadFile, HTTPException, Request, Form, BackgroundTasks
from fastapi.responses import HTMLResponse, FileResponse, JSONResponse
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates
from pydantic import BaseModel, Field, HttpUrl
import uvicorn
import yt_dlp

# Setup directories first (before FastAPI initialization)
UPLOAD_DIR = Path("uploads")
OUTPUT_DIR = Path("outputs")
TEMP_DIR = Path("temp")
STATIC_DIR = Path("static")
TEMPLATES_DIR = Path("templates")
YOUTUBE_DIR = Path("youtube")

# Create all directories before FastAPI tries to mount them
for directory in [UPLOAD_DIR, OUTPUT_DIR, TEMP_DIR, STATIC_DIR, TEMPLATES_DIR, YOUTUBE_DIR]:
    directory.mkdir(exist_ok=True)

# Check if ffmpeg is installed
def check_ffmpeg():
    try:
        result = subprocess.run(['ffmpeg', '-version'],
                                capture_output=True, text=True, check=True)
        return True, result.stdout.split('\n')[0]
    except (subprocess.CalledProcessError, FileNotFoundError):
        return False, "FFmpeg not found"

# Pydantic models
class TrimRequest(BaseModel):
    filename: str
    start_time: float = Field(ge=0, description="Start time in seconds")
    end_time: float = Field(gt=0, description="End time in seconds")
    output_filename: str
    export_format: str = Field(default="same", description="Export format: same, mp4, mp3, wav")

class YouTubeRequest(BaseModel):
    url: HttpUrl
    quality: str = Field(default="best", description="Video quality: best, worst, 720p, 480p, etc.")

class MediaInfo(BaseModel):
    filename: str
    duration: float
    format: str
    video_codec: Optional[str] = None
    audio_codec: Optional[str] = None
    resolution: Optional[str] = None
    file_size: int
    source: str = "local"  # "local" or "youtube"
    title: Optional[str] = None

# Initialize FastAPI app
app = FastAPI(
    title="Video & Audio Trimmer with YouTube Support",
    description="Lightweight web-based media trimming tool with YouTube download",
    version="2.0.0"
)

# Mount static files and templates
app.mount("/static", StaticFiles(directory="static"), name="static")
app.mount("/uploads", StaticFiles(directory="uploads"), name="uploads")
app.mount("/outputs", StaticFiles(directory="outputs"), name="outputs")
app.mount("/youtube", StaticFiles(directory="youtube"), name="youtube")
templates = Jinja2Templates(directory="templates")

# Store uploaded files info
uploaded_files = {}
youtube_downloads = {}

@app.on_event("startup")
async def startup_event():
    ffmpeg_available, ffmpeg_info = check_ffmpeg()
    if ffmpeg_available:
        print(f"✅ FFmpeg is available: {ffmpeg_info}")
    else:
        print(f"❌ FFmpeg not found. Please install FFmpeg to use this tool.")
        print("Visit: https://ffmpeg.org/download.html")

@app.get("/", response_class=HTMLResponse)
async def home(request: Request):
    return templates.TemplateResponse("index.html", {"request": request})

@app.get("/api/ffmpeg-status")
async def ffmpeg_status():
    available, info = check_ffmpeg()
    return {"available": available, "info": info}

class YouTubeDownloadProgress:
    def __init__(self, file_id: str):
        self.file_id = file_id
        self.progress = 0
        self.status = "starting"
        self.error = None

    def hook(self, d):
        if d['status'] == 'downloading':
            if 'total_bytes' in d and d['total_bytes']:
                self.progress = (d['downloaded_bytes'] / d['total_bytes']) * 100
            elif '_percent_str' in d:
                # Parse percentage string like "50.0%"
                percent_str = d['_percent_str'].strip('%')
                try:
                    self.progress = float(percent_str)
                except:
                    pass
            self.status = "downloading"
        elif d['status'] == 'finished':
            self.progress = 100
            self.status = "processing"
        elif d['status'] == 'error':
            self.status = "error"
            self.error = str(d.get('error', 'Unknown error'))

progress_tracker = {}

@app.post("/api/youtube/download")
async def download_youtube_video(request: YouTubeRequest, background_tasks: BackgroundTasks):
    file_id = str(uuid.uuid4())
    url = str(request.url)

    # Initialize progress tracker
    progress_tracker[file_id] = YouTubeDownloadProgress(file_id)

    # Start download in background
    background_tasks.add_task(download_youtube_background, file_id, url, request.quality)

    return {
        "file_id": file_id,
        "status": "started",
        "message": "YouTube download started"
    }

async def download_youtube_background(file_id: str, url: str, quality: str):
    progress = progress_tracker[file_id]

    try:
        # Prepare yt-dlp options
        output_path = YOUTUBE_DIR / f"{file_id}.%(ext)s"

        ydl_opts = {
            'outtmpl': str(output_path),
            'progress_hooks': [progress.hook],
            'format': 'best[height<=720]' if quality == "720p" else
            'best[height<=480]' if quality == "480p" else
            'worst' if quality == "worst" else 'best',
        }

        # Download video
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            # Get video info first
            info = ydl.extract_info(url, download=False)
            title = info.get('title', 'Unknown')
            duration = info.get('duration', 0)

            # Download the video
            ydl.download([url])

        # Find the downloaded file
        downloaded_files = list(YOUTUBE_DIR.glob(f"{file_id}.*"))
        if not downloaded_files:
            raise Exception("Downloaded file not found")

        downloaded_file = downloaded_files[0]

        # Get media info
        media_info = get_media_info(downloaded_file)
        media_info.filename = downloaded_file.name
        media_info.source = "youtube"
        media_info.title = title

        # Store in youtube_downloads
        youtube_downloads[file_id] = {
            "file_id": file_id,
            "original_name": title,
            "filename": downloaded_file.name,
            "info": media_info,
            "download_time": datetime.now(),
            "url": url
        }

        progress.status = "completed"

    except Exception as e:
        progress.status = "error"
        progress.error = str(e)

@app.get("/api/youtube/progress/{file_id}")
async def get_youtube_progress(file_id: str):
    if file_id not in progress_tracker:
        raise HTTPException(status_code=404, detail="Download not found")

    progress = progress_tracker[file_id]
    result = {
        "file_id": file_id,
        "progress": progress.progress,
        "status": progress.status
    }

    if progress.error:
        result["error"] = progress.error

    # If completed, include file info
    if progress.status == "completed" and file_id in youtube_downloads:
        result["file_info"] = {
            "file_id": file_id,
            "filename": youtube_downloads[file_id]["filename"],
            "original_name": youtube_downloads[file_id]["original_name"],
            "info": youtube_downloads[file_id]["info"].dict()
        }

    return result

@app.post("/api/upload")
async def upload_file(file: UploadFile = File(...)):
    if not file.filename:
        raise HTTPException(status_code=400, detail="No file selected")

    # Check file extension
    allowed_extensions = {'.mp4', '.avi', '.mov', '.mkv', '.mp3', '.wav', '.m4a', '.aac', '.flac'}
    file_ext = Path(file.filename).suffix.lower()
    if file_ext not in allowed_extensions:
        raise HTTPException(status_code=400, detail=f"Unsupported file type: {file_ext}")

    # Generate unique filename
    file_id = str(uuid.uuid4())
    filename = f"{file_id}{file_ext}"
    file_path = UPLOAD_DIR / filename

    # Save uploaded file
    try:
        with open(file_path, "wb") as buffer:
            shutil.copyfileobj(file.file, buffer)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to save file: {str(e)}")

    # Get media info
    try:
        media_info = get_media_info(file_path)
        media_info.filename = filename
        media_info.source = "local"
        uploaded_files[file_id] = {
            "file_id": file_id,
            "original_name": file.filename,
            "filename": filename,
            "info": media_info,
            "upload_time": datetime.now()
        }

        return {
            "file_id": file_id,
            "filename": filename,
            "original_name": file.filename,
            "info": media_info.dict()
        }
    except Exception as e:
        # Clean up file if info extraction fails
        file_path.unlink(missing_ok=True)
        raise HTTPException(status_code=500, detail=f"Failed to process file: {str(e)}")

def get_media_info(file_path: Path) -> MediaInfo:
    """Extract media information using ffprobe"""
    try:
        # Get basic info
        cmd = [
            'ffprobe', '-v', 'quiet', '-print_format', 'json', '-show_format',
            '-show_streams', str(file_path)
        ]
        result = subprocess.run(cmd, capture_output=True, text=True, check=True)

        import json
        data = json.loads(result.stdout)

        format_info = data.get('format', {})
        streams = data.get('streams', [])

        # Extract information
        duration = float(format_info.get('duration', 0))
        format_name = format_info.get('format_name', 'unknown')
        file_size = int(format_info.get('size', 0))

        video_codec = None
        audio_codec = None
        resolution = None

        for stream in streams:
            if stream.get('codec_type') == 'video':
                video_codec = stream.get('codec_name')
                width = stream.get('width')
                height = stream.get('height')
                if width and height:
                    resolution = f"{width}x{height}"

            elif stream.get('codec_type') == 'audio':
                audio_codec = stream.get('codec_name')

        return MediaInfo(
            filename="",  # Will be set by caller
            duration=duration,
            format=format_name,
            video_codec=video_codec,
            audio_codec=audio_codec,
            resolution=resolution,
            file_size=file_size
        )

    except subprocess.CalledProcessError as e:
        raise Exception(f"FFprobe error: {e}")
    except json.JSONDecodeError:
        raise Exception("Failed to parse media information")

@app.post("/api/trim")
async def trim_media(request: TrimRequest):
    ffmpeg_available, _ = check_ffmpeg()
    if not ffmpeg_available:
        raise HTTPException(status_code=503, detail="FFmpeg not available")

    # Find the file (check both local and YouTube)
    file_info = None
    source_dir = None

    # Check local files first
    for file_id, info in uploaded_files.items():
        if info["filename"] == request.filename:
            file_info = info
            source_dir = UPLOAD_DIR
            break

    # Check YouTube files if not found in local
    if not file_info:
        for file_id, info in youtube_downloads.items():
            if info["filename"] == request.filename:
                file_info = info
                source_dir = YOUTUBE_DIR
                break

    if not file_info:
        raise HTTPException(status_code=404, detail="File not found")

    input_path = source_dir / request.filename
    if not input_path.exists():
        raise HTTPException(status_code=404, detail="Input file not found")

    # Validate times
    if request.start_time >= request.end_time:
        raise HTTPException(status_code=400, detail="Start time must be less than end time")

    if request.end_time > file_info["info"].duration:
        raise HTTPException(status_code=400, detail="End time exceeds file duration")

    # Determine output format and extension
    original_ext = Path(request.filename).suffix
    export_format = request.export_format.lower()

    if export_format == "same":
        output_ext = original_ext
        codec_args = ['-c', 'copy']  # Copy streams without re-encoding
    elif export_format == "mp4":
        output_ext = ".mp4"
        codec_args = ['-c:v', 'libx264', '-c:a', 'aac']
    elif export_format == "mp3":
        output_ext = ".mp3"
        codec_args = ['-vn', '-c:a', 'libmp3lame', '-q:a', '2']  # Audio only
    elif export_format == "wav":
        output_ext = ".wav"
        codec_args = ['-vn', '-c:a', 'pcm_s16le']  # Audio only
    else:
        raise HTTPException(status_code=400, detail="Unsupported export format")

    # Generate output filename
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    safe_filename = "".join(c for c in request.output_filename if c.isalnum() or c in "._-")
    if not safe_filename:
        safe_filename = f"trimmed_{timestamp}"

    # Ensure proper extension
    if not safe_filename.endswith(output_ext):
        safe_filename += output_ext

    output_path = OUTPUT_DIR / safe_filename

    # Prepare ffmpeg command
    duration = request.end_time - request.start_time
    cmd = [
              'ffmpeg', '-y',  # -y to overwrite output files
              '-i', str(input_path),
              '-ss', str(request.start_time),
              '-t', str(duration),
          ] + codec_args + [str(output_path)]

    try:
        # Run ffmpeg
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            check=True,
            timeout=300  # 5 minute timeout
        )

        if not output_path.exists():
            raise Exception("Output file was not created")

        # Get output file info
        output_info = get_media_info(output_path)

        return {
            "success": True,
            "output_filename": safe_filename,
            "output_info": output_info.dict(),
            "download_url": f"/api/download/{safe_filename}",
            "export_format": export_format
        }

    except subprocess.CalledProcessError as e:
        raise HTTPException(
            status_code=500,
            detail=f"FFmpeg error: {e.stderr or e.stdout or 'Unknown error'}"
        )
    except subprocess.TimeoutExpired:
        raise HTTPException(status_code=500, detail="Processing timeout")
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Processing failed: {str(e)}")

@app.get("/api/download/{filename}")
async def download_file(filename: str):
    file_path = OUTPUT_DIR / filename
    if not file_path.exists():
        raise HTTPException(status_code=404, detail="File not found")

    return FileResponse(
        path=file_path,
        filename=filename,
        media_type='application/octet-stream'
    )

@app.get("/api/files")
async def list_files():
    """Get list of all files (local uploads + YouTube downloads)"""
    all_files = []

    # Add local uploaded files
    for file_id, info in uploaded_files.items():
        all_files.append({
            "file_id": file_id,
            "original_name": info["original_name"],
            "filename": info["filename"],
            "info": info["info"].dict() if hasattr(info["info"], 'dict') else info["info"],
            "upload_time": info.get("upload_time", datetime.now()).isoformat(),
            "source": "local"
        })

    # Add YouTube downloaded files
    for file_id, info in youtube_downloads.items():
        all_files.append({
            "file_id": file_id,
            "original_name": info["original_name"],
            "filename": info["filename"],
            "info": info["info"].dict() if hasattr(info["info"], 'dict') else info["info"],
            "upload_time": info.get("download_time", datetime.now()).isoformat(),
            "source": "youtube",
            "url": info.get("url", "")
        })

    return {"files": all_files}

@app.delete("/api/files/{file_id}")
async def delete_file(file_id: str):
    """Delete uploaded or downloaded file"""
    deleted = False

    # Check local files
    if file_id in uploaded_files:
        file_info = uploaded_files[file_id]
        file_path = UPLOAD_DIR / file_info["filename"]
        if file_path.exists():
            file_path.unlink()
        del uploaded_files[file_id]
        deleted = True

    # Check YouTube files
    if file_id in youtube_downloads:
        file_info = youtube_downloads[file_id]
        file_path = YOUTUBE_DIR / file_info["filename"]
        if file_path.exists():
            file_path.unlink()
        del youtube_downloads[file_id]
        deleted = True

    # Clean up progress tracker
    if file_id in progress_tracker:
        del progress_tracker[file_id]

    if not deleted:
        raise HTTPException(status_code=404, detail="File not found")

    return {"success": True, "message": "File deleted"}

@app.delete("/api/files/clear-all")
async def clear_all_files():
    """Clear all uploaded and downloaded files"""
    cleared_count = 0
    errors = []

    # Clear local files
    for file_id, info in list(uploaded_files.items()):
        try:
            file_path = UPLOAD_DIR / info["filename"]
            if file_path.exists():
                file_path.unlink()
            del uploaded_files[file_id]
            cleared_count += 1
        except Exception as e:
            errors.append(f"Failed to delete local file {info['filename']}: {str(e)}")

    # Clear YouTube files
    for file_id, info in list(youtube_downloads.items()):
        try:
            file_path = YOUTUBE_DIR / info["filename"]
            if file_path.exists():
                file_path.unlink()
            del youtube_downloads[file_id]
            cleared_count += 1
        except Exception as e:
            errors.append(f"Failed to delete YouTube file {info['filename']}: {str(e)}")

    # Clear progress trackers
    progress_tracker.clear()

    # Clean up any orphaned files in directories
    try:
        # Clean uploads directory
        for file_path in UPLOAD_DIR.iterdir():
            if file_path.is_file():
                file_path.unlink()

        # Clean youtube directory
        for file_path in YOUTUBE_DIR.iterdir():
            if file_path.is_file():
                file_path.unlink()

        # Clean outputs directory (optional - remove old processed files)
        for file_path in OUTPUT_DIR.iterdir():
            if file_path.is_file():
                file_path.unlink()

    except Exception as e:
        errors.append(f"Failed to clean directories: {str(e)}")

    if errors:
        return {
            "success": True,
            "cleared_count": cleared_count,
            "errors": errors,
            "message": f"Cleared {cleared_count} files with some errors"
        }
    else:
        return {
            "success": True,
            "cleared_count": cleared_count,
            "message": f"Successfully cleared all {cleared_count} files"
        }

if __name__ == "__main__":
    uvicorn.run("main:app", host="127.0.0.1", port=8000, reload=True)