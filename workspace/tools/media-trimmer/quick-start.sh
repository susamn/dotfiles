#!/bin/bash

VENV_DIR="venv"
SCRIPT_DIR="$TOOLS_PATH/media-trimmer"
PID_FILE="$SCRIPT_DIR/video-trimmer.pid"
LOG_FILE="$SCRIPT_DIR/video-trimmer.log"

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

# Function to check FFmpeg installation
check_ffmpeg() {
    if command -v ffmpeg > /dev/null 2>&1; then
        return 0
    else
        echo "⚠️  Warning: FFmpeg not found"
        echo "Video trimming will not work without FFmpeg"
        echo "Install FFmpeg:"
        echo "  Ubuntu/Debian: sudo apt install ffmpeg"
        echo "  macOS: brew install ffmpeg"
        echo "  CentOS/RHEL: sudo dnf install ffmpeg"
        echo ""
        read -p "Continue without FFmpeg? (y/N): " continue_without_ffmpeg
        if [[ ! "$continue_without_ffmpeg" =~ ^[Yy]$ ]]; then
            exit 1
        fi
        return 1
    fi
}

# Function to start the application
start_app() {
    if is_running; then
        local pid=$(cat "$PID_FILE")
        echo "Video & Audio Trimmer is already running (PID: $pid)"
        echo "Access at: http://127.0.0.1:32100"
        return
    fi

    # Check Python version
    if ! command -v python3 &> /dev/null; then
        echo "❌ Error: Python 3 is not installed or not in PATH"
        echo "Please install Python 3.7 or higher"
        exit 1
    fi

    # Check if main.py exists
    if [ ! -f "$SCRIPT_DIR/main.py" ]; then
        echo "❌ Error: main.py not found in $SCRIPT_DIR"
        echo "Please ensure all files are in the correct directory"
        exit 1
    fi

    # Create venv if it doesn't exist
    if [ ! -d "$SCRIPT_DIR/$VENV_DIR" ]; then
        echo "Creating virtual environment..."
        python3 -m venv "$SCRIPT_DIR/$VENV_DIR"

        # Upgrade pip
        echo "Upgrading pip..."
        "$SCRIPT_DIR/$VENV_DIR/bin/pip" install --upgrade pip

        # Install dependencies
        if [ -f "$SCRIPT_DIR/requirements.txt" ]; then
            echo "Installing dependencies..."
            "$SCRIPT_DIR/$VENV_DIR/bin/pip" install -r "$SCRIPT_DIR/requirements.txt"
        else
            echo "❌ Error: requirements.txt not found"
            exit 1
        fi
    fi

    # Debug: Check if uvicorn is installed in venv
    if ! "$SCRIPT_DIR/$VENV_DIR/bin/python" -c "import uvicorn, fastapi" 2>/dev/null; then
        echo "Installing missing dependencies..."
        "$SCRIPT_DIR/$VENV_DIR/bin/pip" install -r "$SCRIPT_DIR/requirements.txt"
    fi

    # Check FFmpeg (with option to continue without it)
    check_ffmpeg

    # Create necessary directories
    mkdir -p "$SCRIPT_DIR/uploads" "$SCRIPT_DIR/outputs" "$SCRIPT_DIR/temp" "$SCRIPT_DIR/templates"

    echo "Starting Video & Audio Trimmer in background..."
    cd "$SCRIPT_DIR"

    # Start in background using uvicorn directly
    nohup "$SCRIPT_DIR/$VENV_DIR/bin/python" -m uvicorn main:app --host 127.0.0.1 --port 32100 --reload > "$LOG_FILE" 2>&1 &
    local pid=$!

    # Save PID
    echo "$pid" > "$PID_FILE"

    # Wait a moment and check if it started successfully
    sleep 3
    if is_running; then
        echo "✅ Video & Audio Trimmer started successfully (PID: $pid)"
        echo "🌐 Access at: http://127.0.0.1:32100"
        echo "📋 Logs: $LOG_FILE"
        echo ""
        echo "Use '$0 logs' to view logs"
        echo "Use '$0 stop' to stop the server"
        echo "Use '$0 open' to open in browser"
    else
        echo "❌ Failed to start Video & Audio Trimmer"
        echo "Check logs: $LOG_FILE"
        rm -f "$PID_FILE"
        exit 1
    fi
}

# Function to stop the application
stop_app() {
    if ! is_running; then
        echo "Video & Audio Trimmer is not running"
        return
    fi

    local pid=$(cat "$PID_FILE")
    echo "Stopping Video & Audio Trimmer (PID: $pid)..."

    # Try graceful shutdown first
    kill "$pid" 2>/dev/null

    # Wait up to 10 seconds for graceful shutdown
    for i in {1..10}; do
        if ! ps -p "$pid" > /dev/null 2>&1; then
            echo "✅ Video & Audio Trimmer stopped successfully"
            rm -f "$PID_FILE"
            return
        fi
        sleep 1
    done

    # Force kill if still running
    echo "Force killing process..."
    kill -9 "$pid" 2>/dev/null
    rm -f "$PID_FILE"
    echo "✅ Video & Audio Trimmer force stopped"
}

# Function to show status
show_status() {
    if is_running; then
        local pid=$(cat "$PID_FILE")
        echo "✅ Video & Audio Trimmer is running (PID: $pid)"
        echo "🌐 Access at: http://127.0.0.1:32100"
        echo "📋 Logs: $LOG_FILE"

        # Show FFmpeg status
        if command -v ffmpeg > /dev/null 2>&1; then
            echo "✅ FFmpeg is available"
        else
            echo "⚠️  FFmpeg not found (trimming disabled)"
        fi
    else
        echo "❌ Video & Audio Trimmer is not running"
    fi
}

# Function to show logs
show_logs() {
    if [ -f "$LOG_FILE" ]; then
        echo "📋 Recent logs (last 20 lines):"
        echo "================================"
        tail -20 "$LOG_FILE"
    else
        echo "❌ No log file found"
    fi
}

# Function to follow logs in real-time
follow_logs() {
    if [ -f "$LOG_FILE" ]; then
        echo "📋 Following logs (press Ctrl+C to stop):"
        echo "=========================================="
        tail -f "$LOG_FILE"
    else
        echo "❌ No log file found"
    fi
}

# Function to open the URL in the default browser
open_url() {
    if ! is_running; then
        echo "❌ Video & Audio Trimmer is not running"
        echo "Use '$0 start' to start the server first"
        return 1
    fi

    echo "🌐 Opening http://127.0.0.1:32100 in default browser..."

    if command -v xdg-open > /dev/null; then
        xdg-open "http://127.0.0.1:32100" >/dev/null 2>&1 &
    elif command -v gnome-open > /dev/null; then
        gnome-open "http://127.0.0.1:32100" >/dev/null 2>&1 &
    elif command -v open > /dev/null; then
        open "http://127.0.0.1:32100" >/dev/null 2>&1 &
    else
        echo "❌ Could not detect browser command"
        echo "Please open http://127.0.0.1:32100 manually"
    fi
}

# Function to cleanup old files
cleanup() {
    echo "🧹 Cleaning up old files..."

    # Clean uploads older than 24 hours
    if [ -d "$SCRIPT_DIR/uploads" ]; then
        find "$SCRIPT_DIR/uploads" -type f -mtime +1 -delete 2>/dev/null
        echo "✅ Cleaned old upload files"
    fi

    # Clean outputs older than 24 hours
    if [ -d "$SCRIPT_DIR/outputs" ]; then
        find "$SCRIPT_DIR/outputs" -type f -mtime +1 -delete 2>/dev/null
        echo "✅ Cleaned old output files"
    fi

    # Clean temp files
    if [ -d "$SCRIPT_DIR/temp" ]; then
        rm -rf "$SCRIPT_DIR/temp"/*
        echo "✅ Cleaned temp files"
    fi

    # Rotate log file if it's large (>10MB)
    if [ -f "$LOG_FILE" ] && [ $(stat -f%z "$LOG_FILE" 2>/dev/null || stat -c%s "$LOG_FILE" 2>/dev/null || echo 0) -gt 10485760 ]; then
        mv "$LOG_FILE" "${LOG_FILE}.old"
        echo "✅ Rotated large log file"
    fi
}

# Function to show help
show_help() {
    echo "Video & Audio Trimmer Control Script"
    echo "===================================="
    echo ""
    echo "Usage: $0 {start|stop|restart|status|logs|follow|open|cleanup|help}"
    echo ""
    echo "Commands:"
    echo "  start    - Start Video & Audio Trimmer in background (default)"
    echo "  stop     - Stop Video & Audio Trimmer"
    echo "  restart  - Restart Video & Audio Trimmer"
    echo "  status   - Check if Video & Audio Trimmer is running"
    echo "  logs     - Show recent logs (last 20 lines)"
    echo "  follow   - Follow logs in real-time"
    echo "  open     - Open Video & Audio Trimmer in default browser"
    echo "  cleanup  - Clean up old files and logs"
    echo "  help     - Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                    # Start the server"
    echo "  $0 start              # Start the server"
    echo "  $0 stop               # Stop the server"
    echo "  $0 status             # Check if running"
    echo "  $0 open               # Open in browser"
}

# Main script logic
case "${1:-start}" in
    "start")
        echo ""
        echo "🎬 Video & Audio Trimmer"
        echo "========================"
        start_app
        ;;
    "stop")
        stop_app
        ;;
    "restart")
        echo "🔄 Restarting Video & Audio Trimmer..."
        stop_app
        sleep 2
        start_app
        ;;
    "status")
        show_status
        ;;
    "logs")
        show_logs
        ;;
    "follow")
        follow_logs
        ;;
    "open")
        open_url
        ;;
    "cleanup")
        cleanup
        ;;
    "help"|"-h"|"--help")
        show_help
        ;;
    *)
        echo "❌ Unknown command: $1"
        echo ""
        show_help
        exit 1
        ;;
esac