@echo off
REM Multi-Protocol File Explorer Startup Script for Windows
REM Creates virtual environment, installs dependencies, and runs the application

setlocal enabledelayedexpansion

REM Configuration
set VENV_NAME=venv
set APP_NAME=Multi-Protocol File Explorer

REM Colors (if supported)
set RED=[91m
set GREEN=[92m
set YELLOW=[93m
set BLUE=[94m
set NC=[0m

echo %BLUE%================================%NC%
echo %BLUE%  %APP_NAME%%NC%
echo %BLUE%================================%NC%
echo.

REM Change to script directory
cd /d "%~dp0"

REM Check if Python is installed
echo %GREEN%[INFO]%NC% Checking Python installation...
python --version >nul 2>&1
if errorlevel 1 (
    echo %RED%[ERROR]%NC% Python is not installed or not in PATH
    echo %RED%[ERROR]%NC% Please install Python 3.8 or higher from python.org
    pause
    exit /b 1
)

REM Get Python version
for /f "tokens=2" %%i in ('python --version 2^>^&1') do set PYTHON_VERSION=%%i
echo %GREEN%[INFO]%NC% Python !PYTHON_VERSION! found ✓

REM Check if virtual environment exists
echo %GREEN%[INFO]%NC% Checking virtual environment...
if not exist "%VENV_NAME%" (
    echo %GREEN%[INFO]%NC% Creating virtual environment...
    python -m venv "%VENV_NAME%"
    if errorlevel 1 (
        echo %RED%[ERROR]%NC% Failed to create virtual environment
        pause
        exit /b 1
    )
    echo %GREEN%[INFO]%NC% Virtual environment created ✓
) else (
    echo %GREEN%[INFO]%NC% Virtual environment exists ✓
)

REM Activate virtual environment
echo %GREEN%[INFO]%NC% Activating virtual environment...
call "%VENV_NAME%\Scripts\activate.bat"
if errorlevel 1 (
    echo %RED%[ERROR]%NC% Failed to activate virtual environment
    pause
    exit /b 1
)
echo %GREEN%[INFO]%NC% Virtual environment activated ✓

REM Check if requirements.txt exists
if not exist "requirements.txt" (
    echo %RED%[ERROR]%NC% requirements.txt not found
    echo %RED%[ERROR]%NC% Please ensure you're running this script from the project directory
    pause
    exit /b 1
)

REM Upgrade pip
echo %GREEN%[INFO]%NC% Upgrading pip...
python -m pip install --upgrade pip >nul 2>&1

REM Install dependencies
echo %GREEN%[INFO]%NC% Installing dependencies from requirements.txt...
pip install -r requirements.txt
if errorlevel 1 (
    echo %RED%[ERROR]%NC% Failed to install dependencies
    pause
    exit /b 1
)
echo %GREEN%[INFO]%NC% Dependencies installed ✓

REM Check application files
echo %GREEN%[INFO]%NC% Checking application files...
set MISSING_FILES=
if not exist "main.py" set MISSING_FILES=!MISSING_FILES! main.py
if not exist "config_manager.py" set MISSING_FILES=!MISSING_FILES! config_manager.py
if not exist "transfer_manager.py" set MISSING_FILES=!MISSING_FILES! transfer_manager.py
if not exist "connection_panel.py" set MISSING_FILES=!MISSING_FILES! connection_panel.py

if not "!MISSING_FILES!"=="" (
    echo %RED%[ERROR]%NC% Missing required files:!MISSING_FILES!
    echo %RED%[ERROR]%NC% Please ensure all application files are present
    pause
    exit /b 1
)
echo %GREEN%[INFO]%NC% Application files found ✓

REM Start the application
echo.
echo %GREEN%[INFO]%NC% Setup complete! Launching application...
echo.

if exist "launcher.py" (
    python launcher.py
) else if exist "main.py" (
    python main.py
) else (
    echo %RED%[ERROR]%NC% No launcher script found (launcher.py or main.py)
    pause
    exit /b 1
)

REM Deactivate virtual environment
deactivate

echo.
echo %GREEN%[INFO]%NC% Application closed.
pause