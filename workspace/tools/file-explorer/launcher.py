#!/usr/bin/env python3
"""
File Explorer Launcher
Simple script to start the Multi-Protocol File Explorer application
"""

import sys
import os
from pathlib import Path

def check_dependencies():
    """Check if required dependencies are installed"""
    missing_deps = []

    try:
        import PyQt6
    except ImportError:
        missing_deps.append("PyQt6")

    try:
        import paramiko
    except ImportError:
        missing_deps.append("paramiko")

    try:
        import cryptography
    except ImportError:
        missing_deps.append("cryptography")

    if missing_deps:
        print("Missing required dependencies:")
        for dep in missing_deps:
            print(f"  - {dep}")
        print("\nInstall dependencies with:")
        print("  pip install -r requirements.txt")
        print("\nOr install individually:")
        for dep in missing_deps:
            print(f"  pip install {dep}")
        return False

    return True

def check_encryption_support():
    """Check if encryption features are available"""
    try:
        from cryptography.fernet import Fernet
        return True
    except ImportError:
        print("Warning: Encryption support not available.")
        print("Configuration will not be encrypted.")
        print("Install cryptography for encrypted configuration:")
        print("  pip install cryptography")
        return False

def setup_python_path():
    """Add current directory to Python path"""
    current_dir = Path(__file__).parent.absolute()
    if str(current_dir) not in sys.path:
        sys.path.insert(0, str(current_dir))

def main():
    """Main launcher function"""
    print("Multi-Protocol File Explorer")
    print("===========================")

    # Check dependencies
    if not check_dependencies():
        sys.exit(1)

    # Check encryption support (optional)
    encryption_available = check_encryption_support()

    # Setup Python path
    setup_python_path()

    try:
        # Import and run the main application
        print("Starting application...")
        from main import main as app_main
        app_main()
    except ImportError as e:
        print(f"Error importing application: {e}")
        print("Make sure all files are in the correct location.")
        print("Required files: main.py, config_manager.py, etc.")
        sys.exit(1)
    except Exception as e:
        print(f"Error starting application: {e}")
        if "cryptography" in str(e).lower():
            print("\nThis might be a cryptography-related error.")
            print("Try reinstalling cryptography:")
            print("  pip install --upgrade cryptography")
        sys.exit(1)

if __name__ == '__main__':
    main()