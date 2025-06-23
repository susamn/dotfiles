#!/bin/bash

# Multi-Protocol File Explorer Startup Script
# Creates virtual environment, installs dependencies, and runs the application

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
VENV_NAME="venv"
PYTHON_MIN_VERSION="3.8"
APP_NAME="Multi-Protocol File Explorer"

# Functions
print_header() {
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}  $APP_NAME${NC}"
    echo -e "${BLUE}================================${NC}"
    echo
}

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_python() {
    print_status "Checking Python installation..."

    # Check if python3 is available
    if ! command -v python3 &> /dev/null; then
        print_error "Python 3 is not installed or not in PATH"
        print_error "Please install Python 3.8 or higher"
        exit 1
    fi

    # Check Python version
    python_version=$(python3 -c 'import sys; print(".".join(map(str, sys.version_info[:2])))')
    required_version=$PYTHON_MIN_VERSION

    if ! python3 -c "import sys; exit(0 if sys.version_info >= tuple(map(int, '$required_version'.split('.'))) else 1)"; then
        print_error "Python $python_version found, but $required_version or higher is required"
        exit 1
    fi

    print_status "Python $python_version found ✓"
}

check_venv() {
    print_status "Checking virtual environment..."

    if [ ! -d "$VENV_NAME" ]; then
        print_status "Creating virtual environment..."
        python3 -m venv "$VENV_NAME"
        print_status "Virtual environment created ✓"
    else
        print_status "Virtual environment exists ✓"
    fi
}

activate_venv() {
    print_status "Activating virtual environment..."

    # Activate virtual environment
    source "$VENV_NAME/bin/activate"

    # Verify activation
    if [[ "$VIRTUAL_ENV" != "" ]]; then
        print_status "Virtual environment activated ✓"
        print_status "Using Python: $(which python)"
    else
        print_error "Failed to activate virtual environment"
        exit 1
    fi
}

install_dependencies() {
    print_status "Checking dependencies..."

    # Upgrade pip first
    print_status "Upgrading pip..."
    python -m pip install --upgrade pip > /dev/null 2>&1

    # Check if requirements.txt exists
    if [ ! -f "requirements.txt" ]; then
        print_error "requirements.txt not found"
        print_error "Please ensure you're running this script from the project directory"
        exit 1
    fi

    # Install/update dependencies
    print_status "Installing dependencies from requirements.txt..."
    pip install -r requirements.txt

    print_status "Dependencies installed ✓"
}

check_app_files() {
    print_status "Checking application files..."

    required_files=("main.py" "config_manager.py" "transfer_manager.py" "connection_panel.py")
    missing_files=()

    for file in "${required_files[@]}"; do
        if [ ! -f "$file" ]; then
            missing_files+=("$file")
        fi
    done

    if [ ${#missing_files[@]} -ne 0 ]; then
        print_error "Missing required files:"
        for file in "${missing_files[@]}"; do
            echo "  - $file"
        done
        print_error "Please ensure all application files are present"
        exit 1
    fi

    print_status "Application files found ✓"
}

check_display() {
    print_status "Checking display environment..."

    # Check if we're in a graphical environment
    if [ -z "$DISPLAY" ] && [ -z "$WAYLAND_DISPLAY" ] && [ "$XDG_SESSION_TYPE" != "wayland" ]; then
        print_warning "No display environment detected"
        print_warning "This application requires a graphical environment"

        # Check if we're in SSH
        if [ -n "$SSH_CLIENT" ] || [ -n "$SSH_TTY" ]; then
            print_warning "SSH session detected. You may need X11 forwarding:"
            print_warning "  ssh -X username@hostname"
        fi

        echo
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_status "Startup cancelled"
            exit 0
        fi
    else
        print_status "Display environment available ✓"
    fi
}

run_application() {
    print_status "Starting $APP_NAME..."
    echo

    # Try to run the application
    if [ -f "launcher.py" ]; then
        python launcher.py
    elif [ -f "main.py" ]; then
        python main.py
    else
        print_error "No launcher script found (launcher.py or main.py)"
        exit 1
    fi
}

cleanup() {
    if [[ "$VIRTUAL_ENV" != "" ]]; then
        print_status "Deactivating virtual environment..."
        deactivate
    fi
}

main() {
    # Set up cleanup on exit
    trap cleanup EXIT

    print_header

    # Change to script directory
    cd "$(dirname "$0")"

    # Run checks and setup
    check_python
    check_venv
    activate_venv
    install_dependencies
    check_app_files
    check_display

    echo
    print_status "Setup complete! Launching application..."
    echo

    # Run the application
    run_application
}

# Help function
show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Options:"
    echo "  --help, -h     Show this help message"
    echo "  --clean        Remove virtual environment and recreate"
    echo "  --deps-only    Only install dependencies, don't run app"
    echo "  --check        Only run checks, don't install or run"
    echo
    echo "This script will:"
    echo "  1. Check Python installation"
    echo "  2. Create virtual environment if needed"
    echo "  3. Install/update dependencies"
    echo "  4. Launch the File Explorer application"
}

# Handle command line arguments
case "${1:-}" in
    --help|-h)
        show_help
        exit 0
        ;;
    --clean)
        print_status "Cleaning up virtual environment..."
        rm -rf "$VENV_NAME"
        print_status "Virtual environment removed"
        main
        ;;
    --deps-only)
        print_header
        cd "$(dirname "$0")"
        check_python
        check_venv
        activate_venv
        install_dependencies
        print_status "Dependencies installed. Run './start.sh' to launch the app."
        ;;
    --check)
        print_header
        cd "$(dirname "$0")"
        check_python
        check_venv
        check_app_files
        check_display
        print_status "All checks passed ✓"
        ;;
    "")
        main
        ;;
    *)
        print_error "Unknown option: $1"
        echo "Use --help for usage information"
        exit 1
        ;;
esac