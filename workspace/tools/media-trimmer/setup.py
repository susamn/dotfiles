#!/usr/bin/env python3
"""
Setup script for Video & Audio Trimmer
Creates virtual environment and installs dependencies
"""
import os
import sys
import subprocess
import venv
import shutil
from pathlib import Path

def check_python_version():
    """Check if Python version is 3.7 or higher"""
    if sys.version_info < (3, 7):
        print("❌ Python 3.7 or higher is required")
        print(f"Current version: {sys.version}")
        return False
    print(f"✅ Python version: {sys.version.split()[0]}")
    return True

def create_virtual_environment():
    """Create virtual environment"""
    venv_path = Path("venv")

    if venv_path.exists():
        response = input("Virtual environment already exists. Recreate? (y/N): ")
        if response.lower() == 'y':
            print("Removing existing virtual environment...")
            shutil.rmtree(venv_path)
        else:
            print("Using existing virtual environment")
            return venv_path

    print("Creating virtual environment...")
    try:
        venv.create(venv_path, with_pip=True)
        print("✅ Virtual environment created")
        return venv_path
    except Exception as e:
        print(f"❌ Failed to create virtual environment: {e}")
        return None

def get_python_executable(venv_path):
    """Get the Python executable path for the virtual environment"""
    if os.name == 'nt':  # Windows
        return venv_path / "Scripts" / "python.exe"
    else:  # Unix/Linux/MacOS
        return venv_path / "bin" / "python"

def upgrade_pip(python_executable):
    """Upgrade pip in the virtual environment"""
    print("Upgrading pip...")
    try:
        subprocess.check_call([
            str(python_executable), "-m", "pip", "install", "--upgrade", "pip"
        ])
        print("✅ Pip upgraded")
        return True
    except subprocess.CalledProcessError as e:
        print(f"⚠️  Failed to upgrade pip: {e}")
        return False

def install_dependencies(python_executable):
    """Install dependencies from requirements.txt"""
    requirements_file = Path("requirements.txt")

    if not requirements_file.exists():
        print("❌ requirements.txt not found")
        return False

    print("Installing dependencies...")
    try:
        subprocess.check_call([
            str(python_executable), "-m", "pip", "install", "-r", "requirements.txt"
        ])
        print("✅ Dependencies installed")
        return True
    except subprocess.CalledProcessError as e:
        print(f"❌ Failed to install dependencies: {e}")
        return False

def install_additional_dependencies(python_executable):
    """Install additional system dependencies for stop script"""
    print("Installing additional dependencies...")
    try:
        subprocess.check_call([
            str(python_executable), "-m", "pip", "install", "psutil"
        ])
        print("✅ Additional dependencies installed")
        return True
    except subprocess.CalledProcessError as e:
        print(f"⚠️  Failed to install additional dependencies: {e}")
        return False

def create_directories():
    """Create necessary directories"""
    directories = [
        "uploads", "outputs", "temp", "static", "templates"
    ]

    print("Creating directories...")
    for directory in directories:
        Path(directory).mkdir(exist_ok=True)
    print("✅ Directories created")

def create_template_file():
    """Create the HTML template file if it doesn't exist"""
    templates_dir = Path("templates")
    template_file = templates_dir / "index.html"

    if template_file.exists():
        print("✅ Template file already exists")
        return

    print("ℹ️  HTML template file not found")
    print("Please ensure the templates/index.html file is created from the provided template")

def check_ffmpeg():
    """Check if FFmpeg is installed"""
    try:
        result = subprocess.run(['ffmpeg', '-version'],
                                capture_output=True, text=True, check=True)
        version_line = result.stdout.split('\n')[0]
        print(f"✅ FFmpeg is available: {version_line}")
        return True
    except (subprocess.CalledProcessError, FileNotFoundError):
        print("⚠️  FFmpeg not found")
        print("The application will work but trimming functionality will be disabled")
        print("To install FFmpeg:")
        print("  Windows: Download from https://ffmpeg.org/download.html")
        print("  macOS: brew install ffmpeg")
        print("  Ubuntu/Debian: sudo apt install ffmpeg")
        print("  CentOS/RHEL: sudo yum install ffmpeg")
        return False

def create_startup_scripts():
    """Create platform-specific startup scripts"""

    # Windows batch file
    windows_script = Path("start.bat")
    with open(windows_script, 'w') as f:
        f.write('@echo off\n')
        f.write('echo Starting Video & Audio Trimmer...\n')
        f.write('python start.py\n')
        f.write('pause\n')

    # Unix shell script
    unix_script = Path("quick-start.sh")
    with open(unix_script, 'w') as f:
        f.write('#!/bin/bash\n')
        f.write('echo "Starting Video & Audio Trimmer..."\n')
        f.write('python3 start.py\n')

    # Make shell script executable on Unix systems
    if os.name != 'nt':
        os.chmod(unix_script, 0o755)

    print("✅ Startup scripts created")

def verify_installation(python_executable):
    """Verify the installation by importing main modules"""
    print("Verifying installation...")
    try:
        result = subprocess.run([
            str(python_executable), "-c",
            "import fastapi, uvicorn, pydantic, jinja2; print('✅ All modules imported successfully')"
        ], capture_output=True, text=True, check=True)
        print(result.stdout.strip())
        return True
    except subprocess.CalledProcessError as e:
        print(f"❌ Installation verification failed: {e}")
        return False

def main():
    """Main setup function"""
    print("Video & Audio Trimmer - Setup Script")
    print("="*40)

    # Check Python version
    if not check_python_version():
        sys.exit(1)

    # Create virtual environment
    venv_path = create_virtual_environment()
    if not venv_path:
        sys.exit(1)

    # Get Python executable
    python_executable = get_python_executable(venv_path)
    if not python_executable.exists():
        print("❌ Virtual environment Python executable not found")
        sys.exit(1)

    # Upgrade pip
    upgrade_pip(python_executable)

    # Install dependencies
    if not install_dependencies(python_executable):
        sys.exit(1)

    # Install additional dependencies
    install_additional_dependencies(python_executable)

    # Create directories
    create_directories()

    # Create template file check
    create_template_file()

    # Create startup scripts
    create_startup_scripts()

    # Check FFmpeg
    check_ffmpeg()

    # Verify installation
    if not verify_installation(python_executable):
        sys.exit(1)

    print("\n" + "="*50)
    print("🎉 Setup completed successfully!")
    print("="*50)
    print("To start the application:")
    print("  Windows: run 'start.bat' or 'python start.py'")
    print("  Unix/Linux/MacOS: run './quick-start.sh' or 'python3 start.py'")
    print("")
    print("To stop the application:")
    print("  Run 'python stop.py' or press Ctrl+C in the server terminal")
    print("="*50)

if __name__ == "__main__":
    main()