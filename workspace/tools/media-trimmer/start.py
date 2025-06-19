#!/usr/bin/env python3
"""
Simplified start script for Video & Audio Trimmer
Works with the shell script for full functionality
"""
import os
import sys
import subprocess
from pathlib import Path

def check_python_version():
    """Check if Python version is 3.7 or higher"""
    if sys.version_info < (3, 7):
        print("❌ Python 3.7 or higher is required")
        print(f"Current version: {sys.version}")
        sys.exit(1)

def check_ffmpeg():
    """Check if FFmpeg is installed"""
    try:
        result = subprocess.run(['ffmpeg', '-version'],
                                capture_output=True, text=True, check=True)
        version_line = result.stdout.split('\n')[0]
        print(f"✅ FFmpeg is available: {version_line}")
        return True
    except (subprocess.CalledProcessError, FileNotFoundError):
        print("⚠️  FFmpeg not found - trimming functionality will be disabled")
        print("Install FFmpeg from: https://ffmpeg.org/download.html")
        return False

def create_directories():
    """Create necessary directories"""
    directories = ["uploads", "outputs", "temp", "static", "templates"]
    for directory in directories:
        Path(directory).mkdir(exist_ok=True)

def check_dependencies():
    """Check if required dependencies are available"""
    try:
        import fastapi
        import uvicorn
        import pydantic
        import jinja2
        print("✅ All dependencies available")
        return True
    except ImportError as e:
        print(f"❌ Missing dependency: {e}")
        print("Please run the setup script or install dependencies manually")
        return False

def start_server():
    """Start the FastAPI server"""
    import uvicorn

    print("\n" + "="*50)
    print("🎬 Video & Audio Trimmer Server")
    print("="*50)
    print("Server URL: http://127.0.0.1:32100")
    print("Press Ctrl+C to stop the server")
    print("="*50 + "\n")

    try:
        # Start the server
        uvicorn.run(
            "main:app",
            host="127.0.0.1",
            port=32100,
            reload=True,
            reload_dirs=["."],
            reload_includes=["*.py", "*.html"]
        )
    except KeyboardInterrupt:
        print("\n\n🛑 Server stopped by user")
    except Exception as e:
        print(f"\n❌ Server error: {e}")
        sys.exit(1)

def main():
    """Main function - simplified for direct execution"""
    # Basic checks
    check_python_version()

    # Check dependencies
    if not check_dependencies():
        sys.exit(1)

    # Create directories
    create_directories()

    # Check FFmpeg (warn but don't exit)
    check_ffmpeg()

    # Start server
    start_server()

if __name__ == "__main__":
    main()