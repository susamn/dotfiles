# Video & Audio Trimmer - Project Setup Guide

## Complete File Structure

To set up this project, create the following directory structure and files:

```
video-trimmer/
├── main.py                 # FastAPI application (main backend)
├── requirements.txt        # Python dependencies
├── setup.py               # Setup script for virtual environment
├── start.py               # Start server script
├── stop.py                # Stop server script
├── start.bat              # Windows startup script
├── start.sh               # Unix/Linux/macOS startup script
├── README.md              # Project documentation
├── PROJECT_SETUP.md       # This file
├── .gitignore             # Git ignore file
└── templates/
    └── index.html         # Main web interface
```

## Setup Instructions

### Step 1: Create Project Directory
```bash
mkdir video-trimmer
cd video-trimmer
```

### Step 2: Create All Files
Copy all the provided code files into their respective locations:

1. **Backend Files:**
    - `main.py` - The FastAPI application
    - `requirements.txt` - Python package dependencies

2. **Setup and Control Scripts:**
    - `setup.py` - Creates virtual environment and installs dependencies
    - `start.py` - Starts the web server
    - `stop.py` - Stops the web server and cleans up

3. **Platform Scripts:**
    - `start.bat` - Windows batch file for easy startup
    - `start.sh` - Unix shell script for easy startup

4. **Web Interface:**
    - `templates/index.html` - The complete web interface

5. **Documentation:**
    - `README.md` - Complete project documentation
    - `.gitignore` - Git ignore patterns

### Step 3: Create Templates Directory
```bash
mkdir templates
```

### Step 4: Make Shell Script Executable (Unix/Linux/macOS)
```bash
chmod +x quick-start.sh
```

### Step 5: Run Setup
```bash
# This will create virtual environment and install dependencies
python setup.py
# or on some systems:
python3 setup.py
```

### Step 6: Start the Application
```bash
# Option 1: Use start script
python start.py

# Option 2: Use platform-specific script
# Windows:
start.bat

# Unix/Linux/macOS:
./quick-start.sh
```

## Dependencies

The application requires minimal external dependencies:

- **Python 3.7+** (built-in)
- **FFmpeg** (external - for media processing)
- **FastAPI** (installed via pip)
- **Uvicorn** (installed via pip)
- **Pydantic** (installed via pip)
- **Jinja2** (installed via pip)
- **python-multipart** (installed via pip)

## FFmpeg Installation

### Windows
1. Download from https://ffmpeg.org/download.html
2. Extract to a folder (e.g., `C:\ffmpeg`)
3. Add `C:\ffmpeg\bin` to your PATH environment variable

### macOS
```bash
# Using Homebrew
brew install ffmpeg

# Using MacPorts
sudo port install ffmpeg
```

### Ubuntu/Debian
```bash
sudo apt update
sudo apt install ffmpeg
```

### CentOS/RHEL/Fedora
```bash
# CentOS/RHEL 8+
sudo dnf install ffmpeg

# Fedora
sudo dnf install ffmpeg

# Older versions may need EPEL repository
sudo yum install epel-release
sudo yum install ffmpeg
```

## Verification

After setup, verify everything works:

1. **Check Python**: `python --version` (should be 3.7+)
2. **Check FFmpeg**: `ffmpeg -version` (should show version info)
3. **Check Virtual Environment**: Should see `venv/` directory
4. **Check Dependencies**: Run `python start.py` - should start without errors

## Directory Permissions

The application will automatically create these directories:
- `uploads/` - For uploaded media files
- `outputs/` - For processed media files
- `temp/` - For temporary processing files

Ensure the application has write permissions to the project directory.

## Troubleshooting Setup

### Python Version Issues
- Ensure Python 3.7+ is installed
- On some systems, use `python3` instead of `python`
- Update pip: `python -m pip install --upgrade pip`

### Virtual Environment Issues
- Delete `venv/` directory and run `setup.py` again
- Ensure you have `venv` module: `python -m venv --help`

### FFmpeg Issues
- Verify installation: `ffmpeg -version`
- Check PATH environment variable
- Try reinstalling FFmpeg

### Permission Issues
- **Windows**: Run Command Prompt as Administrator
- **Unix/Linux**: Ensure user has write permissions to directory
- **macOS**: Check Gatekeeper settings for downloaded executables

## Security Notes

- The application runs locally on `127.0.0.1:8000`
- Files are processed locally and not sent to external servers
- Uploaded files are stored temporarily and can be cleaned up
- The application includes basic file type validation

## Next Steps

Once setup is complete:
1. Start the application
2. Open http://127.0.0.1:8000 in your browser
3. Upload a video or audio file
4. Use the timeline to select trim points
5. Process and download your trimmed media

The interface is designed to be intuitive and similar to desktop media editing applications.