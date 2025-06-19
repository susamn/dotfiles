@echo off
echo.
echo =====================================
echo  Video & Audio Trimmer
echo =====================================
echo.

REM Check if Python is available
python --version >nul 2>&1
if errorlevel 1 (
    echo Error: Python is not installed or not in PATH
    echo Please install Python 3.7 or higher
    pause
    exit /b 1
)

REM Check if setup has been run
if not exist "venv" (
    echo Error: Virtual environment not found
    echo Please run 'python setup.py' first
    pause
    exit /b 1
)

REM Check if main.py exists
if not exist "main.py" (
    echo Error: main.py not found
    echo Please ensure all files are in the correct directory
    pause
    exit /b 1
)

echo Starting Video & Audio Trimmer...
echo.
echo Server will be available at: http://127.0.0.1:8000
echo Press Ctrl+C to stop the server
echo.

REM Start the application
python start.py

echo.
echo Server stopped.
pause