#!/bin/bash

VENV_DIR="venv"
SCRIPT_DIR="$TOOLS_PATH/helpful-tools"
PID_FILE="$SCRIPT_DIR/helpful-tools.pid"
LOG_FILE="$SCRIPT_DIR/helpful-tools.log"

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

# Function to start the application
start_app() {
    if is_running; then
        local pid=$(cat "$PID_FILE")
        echo "Helpful-Tools is already running (PID: $pid)"
        echo "Access at: http://127.0.0.1:8000"
        return
    fi

    # Create venv if it doesn't exist
    if [ ! -d "$SCRIPT_DIR/$VENV_DIR" ]; then
        echo "Creating virtual environment..."
        python3 -m venv "$SCRIPT_DIR/$VENV_DIR"
        echo "Installing dependencies..."
        "$SCRIPT_DIR/$VENV_DIR/bin/pip" install -r "$SCRIPT_DIR/requirements.txt"
    fi

    # Debug: Check if uvicorn is installed in venv
    if ! "$SCRIPT_DIR/$VENV_DIR/bin/python" -c "import uvicorn" 2>/dev/null; then
        echo "Installing missing dependencies..."
        "$SCRIPT_DIR/$VENV_DIR/bin/pip" install -r "$SCRIPT_DIR/requirements.txt"
    fi

    echo "Starting Helpful-Tools in background..."
    cd "$SCRIPT_DIR"

    # Start in background with explicit paths
    nohup "$SCRIPT_DIR/$VENV_DIR/bin/python" "$SCRIPT_DIR/start.py" > "$LOG_FILE" 2>&1 &
    local pid=$!

    # Save PID
    echo "$pid" > "$PID_FILE"

    # Wait a moment and check if it started successfully
    sleep 2
    if is_running; then
        echo "Helpful-Tools started successfully (PID: $pid)"
        echo "Access at: http://127.0.0.1:8000"
        echo "Logs: $LOG_FILE"
    else
        echo "Failed to start Helpful-Tools"
        echo "Check logs: $LOG_FILE"
        rm -f "$PID_FILE"
    fi
}

# Function to stop the application
stop_app() {
    if ! is_running; then
        echo "Helpful-Tools is not running"
        return
    fi

    local pid=$(cat "$PID_FILE")
    echo "Stopping Helpful-Tools (PID: $pid)..."

    # Try graceful shutdown first
    kill "$pid" 2>/dev/null

    # Wait up to 5 seconds for graceful shutdown
    for i in {1..5}; do
        if ! ps -p "$pid" > /dev/null 2>&1; then
            echo "Helpful-Tools stopped successfully"
            rm -f "$PID_FILE"
            return
        fi
        sleep 1
    done

    # Force kill if still running
    echo "Force killing process..."
    kill -9 "$pid" 2>/dev/null
    rm -f "$PID_FILE"
    echo "Helpful-Tools force stopped"
}

# Function to show status
show_status() {
    if is_running; then
        local pid=$(cat "$PID_FILE")
        echo "Helpful-Tools is running (PID: $pid)"
        echo "Access at: http://127.0.0.1:8000"
        echo "Logs: $LOG_FILE"
    else
        echo "Helpful-Tools is not running"
    fi
}

# Function to show logs
show_logs() {
    if [ -f "$LOG_FILE" ]; then
        echo "Recent logs:"
        tail -20 "$LOG_FILE"
    else
        echo "No log file found"
    fi
}

# Main script logic
case "${1:-start}" in
    "start")
        start_app
        ;;
    "stop")
        stop_app
        ;;
    "restart")
        stop_app
        sleep 1
        start_app
        ;;
    "status")
        show_status
        ;;
    "logs")
        show_logs
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status|logs}"
        echo "  start   - Start Helpful-Tools in background (default)"
        echo "  stop    - Stop Helpful-Tools"
        echo "  restart - Restart Helpful-Tools"
        echo "  status  - Check if Helpful-Tools is running"
        echo "  logs    - Show recent logs"
        exit 1
        ;;
esac