#!/bin/bash

# API Testing Tool - Start/Stop Script
# Usage: ./api-tool.sh [start|stop|restart|status]

VENV_DIR="venv"
SCRIPT_DIR="$TOOLS_PATH/api-testing-tool"
PID_FILE="$SCRIPT_DIR/api-tool.pid"
LOG_FILE="$SCRIPT_DIR/api-tool.log"
MAIN_SCRIPT="tool.py"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}   API Testing Tool Manager${NC}"
    echo -e "${BLUE}================================${NC}"
}

# Function to check if process is running
is_running() {
    if [ -f "$PID_FILE" ]; then
        local pid=$(cat "$PID_FILE")
        if ps -p "$pid" > /dev/null 2>&1; then
            return 0
        else
            rm -f "$PID_FILE"
            return 1
        fi
    fi
    return 1
}

# Function to check Qt and GUI dependencies
check_gui_dependencies() {
    print_status "Checking GUI dependencies..."
    
    # Check if we're in a headless environment
    if [ -z "$DISPLAY" ] && [ -z "$WAYLAND_DISPLAY" ]; then
        print_warning "No display server detected"
        print_warning "API Testing Tool requires a GUI environment"
        echo ""
        echo "If you're using SSH, try:"
        echo "  ssh -X user@server  (for X11 forwarding)"
        echo "  ssh -Y user@server  (for trusted X11 forwarding)"
        echo ""
        read -p "Continue anyway? (y/N): " continue_headless
        if [[ ! "$continue_headless" =~ ^[Yy]$ ]]; then
            exit 1
        fi
        return 1
    fi
    
    # Check for required system libraries (Ubuntu/Debian)
    if command -v apt &> /dev/null; then
        local missing_packages=()
        
        # Check for Qt libraries
        if ! ldconfig -p | grep -q libQt6; then
            if ! dpkg -l | grep -q python3-pyqt6; then
                missing_packages+=("python3-pyqt6")
            fi
        fi
        
        # Check for additional GUI libraries
        if ! ldconfig -p | grep -q libxcb; then
            if ! dpkg -l | grep -q libxcb-xinerama0; then
                missing_packages+=("libxcb-xinerama0")
            fi
        fi
        
        if [ ${#missing_packages[@]} -gt 0 ]; then
            print_warning "Missing system packages detected"
            echo "Install with: sudo apt install ${missing_packages[*]}"
            echo ""
            read -p "Continue without system packages? (y/N): " continue_without_packages
            if [[ ! "$continue_without_packages" =~ ^[Yy]$ ]]; then
                exit 1
            fi
        fi
    fi
    
    return 0
}

# Function to check Python and dependencies
check_python_dependencies() {
    print_status "Checking Python dependencies..."
    
    # Check Python version
    if ! command -v python3 &> /dev/null; then
        print_error "Python 3 is not installed or not in PATH"
        echo "Please install Python 3.8 or higher"
        exit 1
    fi
    
    # Check Python version is 3.8+
    local python_version=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
    local required_version="3.8"
    
    if ! python3 -c "import sys; exit(0 if sys.version_info >= (3, 8) else 1)" 2>/dev/null; then
        print_error "Python version $python_version detected"
        print_error "API Testing Tool requires Python 3.8 or higher"
        exit 1
    fi
    
    print_status "Python $python_version detected ✓"
    return 0
}

# Function to setup virtual environment
setup_virtualenv() {
    print_status "Setting up virtual environment..."
    
    # Create venv if it doesn't exist
    if [ ! -d "$SCRIPT_DIR/$VENV_DIR" ]; then
        print_status "Creating virtual environment..."
        python3 -m venv "$SCRIPT_DIR/$VENV_DIR"
        
        if [ $? -ne 0 ]; then
            print_error "Failed to create virtual environment"
            exit 1
        fi
        
        # Upgrade pip
        print_status "Upgrading pip..."
        "$SCRIPT_DIR/$VENV_DIR/bin/pip" install --upgrade pip
        
        # Install dependencies
        if [ -f "$SCRIPT_DIR/requirements.txt" ]; then
            print_status "Installing dependencies..."
            "$SCRIPT_DIR/$VENV_DIR/bin/pip" install -r "$SCRIPT_DIR/requirements.txt"
            
            if [ $? -ne 0 ]; then
                print_error "Failed to install dependencies"
                exit 1
            fi
        else
            print_warning "requirements.txt not found, installing basic dependencies..."
            "$SCRIPT_DIR/$VENV_DIR/bin/pip" install PyQt6 httpx websocket-client
        fi
    else
        print_status "Virtual environment already exists ✓"
    fi
    
    # Verify PyQt6 installation
    if ! "$SCRIPT_DIR/$VENV_DIR/bin/python" -c "import PyQt6.QtWidgets" 2>/dev/null; then
        print_status "Installing missing PyQt6 dependencies..."
        "$SCRIPT_DIR/$VENV_DIR/bin/pip" install PyQt6 httpx websocket-client
    fi
    
    return 0
}

# Function to start the application
start_app() {
    print_header
    
    if is_running; then
        local pid=$(cat "$PID_FILE")
        print_status "API Testing Tool is already running (PID: $pid)"
        return 0
    fi
    
    check_python_dependencies
    check_gui_dependencies
    
    # Check if main script exists
    if [ ! -f "$SCRIPT_DIR/$MAIN_SCRIPT" ]; then
        print_error "$MAIN_SCRIPT not found in $SCRIPT_DIR"
        echo "Please ensure all files are in the correct directory"
        exit 1
    fi
    
    setup_virtualenv
    
    print_status "Starting API Testing Tool..."
    
    # Start the application in background
    cd "$SCRIPT_DIR"
    nohup "$SCRIPT_DIR/$VENV_DIR/bin/python" "$MAIN_SCRIPT" > "$LOG_FILE" 2>&1 &
    local pid=$!
    
    # Save PID
    echo $pid > "$PID_FILE"
    
    # Wait a moment and check if it's still running
    sleep 2
    if ps -p $pid > /dev/null 2>&1; then
        print_status "API Testing Tool started successfully (PID: $pid)"
        print_status "Log file: $LOG_FILE"
        print_status "You can now use the API Testing Tool GUI"
    else
        print_error "Failed to start API Testing Tool"
        print_error "Check log file: $LOG_FILE"
        rm -f "$PID_FILE"
        exit 1
    fi
}

# Function to stop the application
stop_app() {
    print_header
    
    if ! is_running; then
        print_status "API Testing Tool is not running"
        return 0
    fi
    
    local pid=$(cat "$PID_FILE")
    print_status "Stopping API Testing Tool (PID: $pid)..."
    
    # Try graceful shutdown first
    kill -TERM $pid 2>/dev/null
    
    # Wait up to 10 seconds for graceful shutdown
    for i in {1..10}; do
        if ! ps -p $pid > /dev/null 2>&1; then
            print_status "API Testing Tool stopped gracefully"
            rm -f "$PID_FILE"
            return 0
        fi
        sleep 1
    done
    
    # Force kill if still running
    print_warning "Forcing shutdown..."
    kill -KILL $pid 2>/dev/null
    rm -f "$PID_FILE"
    print_status "API Testing Tool stopped"
}

# Function to restart the application
restart_app() {
    print_header
    print_status "Restarting API Testing Tool..."
    stop_app
    sleep 2
    start_app
}

# Function to show status
show_status() {
    print_header
    
    if is_running; then
        local pid=$(cat "$PID_FILE")
        local memory=$(ps -p $pid -o rss= 2>/dev/null | awk '{print int($1/1024)"MB"}')
        local cpu=$(ps -p $pid -o %cpu= 2>/dev/null | awk '{print $1"%"}')
        local start_time=$(ps -p $pid -o lstart= 2>/dev/null)
        
        print_status "API Testing Tool is running"
        echo "  PID: $pid"
        echo "  Memory: $memory"
        echo "  CPU: $cpu"
        echo "  Started: $start_time"
        echo "  Log: $LOG_FILE"
        echo "  Data directory: $SCRIPT_DIR"
    else
        print_status "API Testing Tool is not running"
    fi
    
    # Show recent log entries if log file exists
    if [ -f "$LOG_FILE" ]; then
        echo ""
        echo "Recent log entries:"
        echo "==================="
        tail -n 5 "$LOG_FILE" 2>/dev/null || echo "No log entries found"
    fi
}

# Function to show logs
show_logs() {
    print_header
    
    if [ -f "$LOG_FILE" ]; then
        print_status "Showing API Testing Tool logs (last 50 lines)"
        echo "Press Ctrl+C to exit"
        echo "=================================="
        tail -n 50 -f "$LOG_FILE"
    else
        print_warning "Log file not found: $LOG_FILE"
    fi
}

# Function to clean up
cleanup() {
    print_header
    print_warning "This will remove all data and virtual environment"
    read -p "Are you sure? (y/N): " confirm
    
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        stop_app
        
        print_status "Removing virtual environment..."
        rm -rf "$SCRIPT_DIR/$VENV_DIR"
        
        print_status "Removing data files..."
        rm -f "$SCRIPT_DIR"/*.json
        rm -f "$SCRIPT_DIR"/*.log
        rm -f "$SCRIPT_DIR"/*.pid
        
        print_status "Cleanup completed"
    else
        print_status "Cleanup cancelled"
    fi
}

# Function to show help
show_help() {
    print_header
    echo "Usage: $0 [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  start     Start the API Testing Tool"
    echo "  stop      Stop the API Testing Tool"
    echo "  restart   Restart the API Testing Tool"
    echo "  status    Show current status"
    echo "  logs      Show and follow logs"
    echo "  cleanup   Remove all data and virtual environment"
    echo "  help      Show this help message"
    echo ""
    echo "Files:"
    echo "  Script dir: $SCRIPT_DIR"
    echo "  Log file:   $LOG_FILE"
    echo "  PID file:   $PID_FILE"
    echo ""
    echo "Examples:"
    echo "  $0 start      # Start the tool"
    echo "  $0 status     # Check if running"
    echo "  $0 logs       # Monitor logs"
    echo "  $0 restart    # Restart the tool"
}

# Create requirements.txt if it doesn't exist
create_requirements() {
    if [ ! -f "$SCRIPT_DIR/requirements.txt" ]; then
        print_status "Creating requirements.txt..."
        cat > "$SCRIPT_DIR/requirements.txt" << EOF
PyQt6>=6.4.0
httpx>=0.24.0
websocket-client>=1.6.0
EOF
    fi
}

# Main script logic
main() {
    # Ensure script directory exists
    if [ ! -d "$SCRIPT_DIR" ]; then
        print_error "Script directory not found: $SCRIPT_DIR"
        print_error "Please set TOOLS_PATH environment variable"
        exit 1
    fi
    
    # Create requirements if needed
    create_requirements
    
    # Handle commands
    case "${1:-start}" in
        "start")
            start_app
            ;;
        "stop")
            stop_app
            ;;
        "restart")
            restart_app
            ;;
        "status")
            show_status
            ;;
        "logs")
            show_logs
            ;;
        "cleanup")
            cleanup
            ;;
        "help"|"-h"|"--help")
            show_help
            ;;
        *)
            print_error "Unknown command: $1"
            echo ""
            show_help
            exit 1
            ;;
    esac
}

# Check if TOOLS_PATH is set
if [ -z "$TOOLS_PATH" ]; then
    print_error "TOOLS_PATH environment variable is not set"
    echo "Please set it to your tools directory:"
    echo "  export TOOLS_PATH=/path/to/your/tools"
    echo "  echo 'export TOOLS_PATH=/path/to/your/tools' >> ~/.bashrc"
    exit 1
fi

# Run main function
main "$@"
