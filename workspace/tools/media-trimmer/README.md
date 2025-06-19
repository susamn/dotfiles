# Video & Audio Trimmer

A lightweight web-based tool for trimming and cropping video and audio files. Built with FastAPI and featuring a clean, Windows-style interface similar to desktop applications.

## Features

- 🎬 **Video & Audio Support**: MP4, AVI, MOV, MKV, MP3, WAV, M4A, AAC, FLAC
- ✂️ **Precise Trimming**: Visual timeline with drag-and-drop handles
- 👀 **Real-time Preview**: Video playback and audio controls
- 📱 **Responsive Design**: Clean, professional interface
- 🚀 **Fast Processing**: Uses FFmpeg with stream copying for speed
- 💾 **Easy Downloads**: Direct download of processed files
- 🔄 **Drag & Drop**: Intuitive file upload

## Prerequisites

- **Python 3.7 or higher**
- **FFmpeg** (required for media processing)

### Installing FFmpeg

#### Windows
1. Download from [https://ffmpeg.org/download.html](https://ffmpeg.org/download.html)
2. Extract and add to PATH

#### macOS
```bash
brew install ffmpeg
```

#### Ubuntu/Debian
```bash
sudo apt update
sudo apt install ffmpeg
```

#### CentOS/RHEL
```bash
sudo yum install ffmpeg
# or for newer versions:
sudo dnf install ffmpeg
```

## Quick Start

### 1. Setup (One-time)
```bash
# Clone or download the project files
# Run the setup script
python setup.py
```

The setup script will:
- Create a virtual environment
- Install all dependencies
- Create necessary directories
- Verify FFmpeg installation

### 2. Start the Server
```bash
# Option 1: Use the start script
python start.py

# Option 2: Use platform scripts
# Windows:
start.bat

# Unix/Linux/MacOS:
./quick-start.sh
```

### 3. Access the Application
Open your web browser and go to: **http://127.0.0.1:8000**

### 4. Stop the Server
```bash
# Option 1: Press Ctrl+C in the terminal
# Option 2: Use the stop script
python stop.py
```

## Usage

1. **Upload Files**: Drag and drop media files or click "Upload Files"
2. **Select File**: Click on a file in the list to preview it
3. **Set Trim Points**:
    - Use the visual timeline to drag start/end handles
    - Or enter precise times in the input fields
4. **Trim**: Click "Trim Selected" and specify output filename
5. **Download**: The trimmed file will automatically download

## File Structure

```
video-trimmer/
├── main.py              # FastAPI application
├── requirements.txt     # Python dependencies
├── setup.py            # Setup script
├── start.py            # Start server script
├── stop.py             # Stop server script
├── start.bat           # Windows startup script
├── start.sh            # Unix startup script
├── README.md           # This file
├── templates/
│   └── index.html      # Web interface
├── uploads/            # Uploaded files (auto-created)
├── outputs/            # Processed files (auto-created)
├── temp/               # Temporary files (auto-created)
└── venv/               # Virtual environment (auto-created)
```

## API Endpoints

- `GET /` - Main web interface
- `POST /api/upload` - Upload media files
- `POST /api/trim` - Trim media files
- `GET /api/files` - List uploaded files
- `DELETE /api/files/{file_id}` - Delete a file
- `GET /api/download/{filename}` - Download processed files
- `GET /api/ffmpeg-status` - Check FFmpeg availability

## Technical Details

### Dependencies
- **FastAPI**: Web framework
- **Uvicorn**: ASGI server
- **Pydantic**: Data validation
- **Jinja2**: Template engine
- **Python-multipart**: File upload support

### Processing
- Uses FFmpeg for media processing
- Stream copying (no re-encoding) for faster processing
- Temporary file management
- Automatic cleanup of old files

### Security
- File type validation
- Safe filename handling
- Temporary file isolation
- No persistent file storage

## Troubleshooting

### FFmpeg Not Found
```
❌ FFmpeg not found
```
**Solution**: Install FFmpeg and ensure it's in your system PATH.

### Port Already in Use
```
Error: Port 8000 is already in use
```
**Solution**: Run `python stop.py` or change the port in `start.py`.

### Permission Errors
**Windows**: Run as Administrator if needed
**Unix/Linux**: Ensure proper file permissions: `chmod +x start.sh`

### Virtual Environment Issues
```
❌ Virtual environment not found
```
**Solution**: Run `python setup.py` to recreate the environment.

## Configuration

### Changing the Port
Edit `start.py` and modify the port parameter:
```python
uvicorn.run("main:app", host="127.0.0.1", port=8080, reload=True)
```

### File Size Limits
FastAPI has default limits. To change them, modify `main.py`:
```python
app = FastAPI(
    title="Video & Audio Trimmer",
    # Add custom configuration here
)
```

### Supported Formats
To add more formats, edit the `allowed_extensions` set in `main.py`:
```python
allowed_extensions = {'.mp4', '.avi', '.mov', '.mkv', '.mp3', '.wav', '.m4a', '.aac', '.flac'}
```

## License

This project is open source. Feel free to use and modify as needed.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## Support

For issues and questions:
1. Check the troubleshooting section
2. Verify FFmpeg installation
3. Check Python and dependency versions
4. Review error messages in the console