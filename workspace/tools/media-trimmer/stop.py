#!/usr/bin/env python3
"""
Simple stop script for Video & Audio Trimmer
For full process management, use the shell script: ./quick-start.sh stop
"""
import os
import sys
import psutil
import time

def find_trimmer_processes():
    """Find running video trimmer processes"""
    processes = []

    for proc in psutil.process_iter(['pid', 'name', 'cmdline']):
        try:
            cmdline = proc.info['cmdline']
            if cmdline:
                cmdline_str = ' '.join(cmdline)
                # Look for uvicorn processes running main:app
                if ('uvicorn' in cmdline_str and 'main:app' in cmdline_str) or \
                        ('python' in cmdline_str and 'main.py' in cmdline_str):
                    processes.append(proc)
        except (psutil.NoSuchProcess, psutil.AccessDenied, psutil.ZombieProcess):
            pass

    return processes

def stop_processes():
    """Stop video trimmer processes"""
    processes = find_trimmer_processes()

    if not processes:
        print("❌ No Video & Audio Trimmer processes found")
        return

    print(f"Found {len(processes)} Video & Audio Trimmer process(es)")

    # Try graceful shutdown first
    for proc in processes:
        try:
            print(f"Stopping process {proc.pid}...")
            proc.terminate()
        except psutil.NoSuchProcess:
            pass

    # Wait for processes to terminate
    gone, alive = psutil.wait_procs(processes, timeout=10)

    # Force kill remaining processes
    if alive:
        print(f"Force killing {len(alive)} remaining process(es)...")
        for proc in alive:
            try:
                proc.kill()
            except psutil.NoSuchProcess:
                pass

        # Final wait
        psutil.wait_procs(alive, timeout=5)

    print("✅ All Video & Audio Trimmer processes stopped")

def cleanup_files():
    """Clean up temporary files"""
    from pathlib import Path

    temp_dir = Path("temp")
    cleaned_count = 0

    # Clean temp directory
    if temp_dir.exists():
        for file_path in temp_dir.iterdir():
            if file_path.is_file():
                try:
                    file_path.unlink()
                    cleaned_count += 1
                except OSError:
                    pass

    if cleaned_count > 0:
        print(f"✅ Cleaned up {cleaned_count} temporary file(s)")

def main():
    """Main function"""
    print("Video & Audio Trimmer - Stop Script")
    print("="*40)

    try:
        # Stop processes
        stop_processes()

        # Clean up temp files
        cleanup_files()

        print("\n✅ Video & Audio Trimmer stopped successfully")
        print("\nNote: For full process management, use './quick-start.sh stop'")

    except Exception as e:
        print(f"\n❌ Error stopping server: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()