# Multi-Protocol File Explorer Makefile

.PHONY: help setup run clean install check test lint format deps-only

# Configuration
VENV_NAME := venv
PYTHON := python3
PIP := $(VENV_NAME)/bin/pip
PYTHON_VENV := $(VENV_NAME)/bin/python

# Default target
help:
	@echo "Multi-Protocol File Explorer"
	@echo "============================"
	@echo ""
	@echo "Available targets:"
	@echo "  setup      - Create virtual environment and install dependencies"
	@echo "  run        - Run the application (creates venv if needed)"
	@echo "  clean      - Remove virtual environment and cache files"
	@echo "  install    - Install/update dependencies only"
	@echo "  check      - Run checks and tests"
	@echo "  test       - Run unit tests (when available)"
	@echo "  lint       - Run code linting (when available)"
	@echo "  format     - Format code with black (when available)"
	@echo "  deps-only  - Install dependencies without running app"
	@echo ""
	@echo "Quick start:"
	@echo "  make run   # Sets up everything and runs the app"

# Create virtual environment
$(VENV_NAME):
	@echo "Creating virtual environment..."
	$(PYTHON) -m venv $(VENV_NAME)
	@echo "Virtual environment created ✓"

# Install dependencies
install: $(VENV_NAME)
	@echo "Installing dependencies..."
	$(PIP) install --upgrade pip
	$(PIP) install -r requirements.txt
	@echo "Dependencies installed ✓"

# Setup everything
setup: install
	@echo "Setup complete ✓"

# Install dependencies only
deps-only: install
	@echo "Dependencies installed. Run 'make run' to start the application."

# Run the application
run: install
	@echo "Starting Multi-Protocol File Explorer..."
	@if [ -f launcher.py ]; then \
		$(PYTHON_VENV) launcher.py; \
	elif [ -f main.py ]; then \
		$(PYTHON_VENV) main.py; \
	else \
		echo "Error: No launcher script found"; \
		exit 1; \
	fi

# Clean up
clean:
	@echo "Cleaning up..."
	rm -rf $(VENV_NAME)
	rm -rf __pycache__
	rm -rf */__pycache__
	rm -rf *.pyc
	rm -rf */*.pyc
	rm -rf .pytest_cache
	rm -rf build
	rm -rf dist
	rm -rf *.egg-info
	@echo "Cleanup complete ✓"

# Development targets (optional)
check: $(VENV_NAME)
	@echo "Running checks..."
	@if [ -f requirements-dev.txt ]; then \
		$(PIP) install -r requirements-dev.txt; \
	fi
	@# Add checks here when available
	@echo "Checks complete ✓"

test: $(VENV_NAME)
	@echo "Running tests..."
	@if [ -d tests ]; then \
		$(PYTHON_VENV) -m pytest tests/; \
	else \
		echo "No tests directory found"; \
	fi

lint: $(VENV_NAME)
	@echo "Running linter..."
	@if command -v $(VENV_NAME)/bin/flake8 >/dev/null 2>&1; then \
		$(VENV_NAME)/bin/flake8 *.py protocols/; \
	else \
		echo "flake8 not installed. Install with: pip install flake8"; \
	fi

format: $(VENV_NAME)
	@echo "Formatting code..."
	@if command -v $(VENV_NAME)/bin/black >/dev/null 2>&1; then \
		$(VENV_NAME)/bin/black *.py protocols/; \
	else \
		echo "black not installed. Install with: pip install black"; \
	fi

# Install development dependencies
dev-deps: $(VENV_NAME)
	@echo "Installing development dependencies..."
	$(PIP) install pytest black flake8 mypy
	@echo "Development dependencies installed ✓"

# Create distributable package
package: clean setup
	@echo "Creating package..."
	$(PYTHON_VENV) setup.py sdist bdist_wheel
	@echo "Package created in dist/ directory"

# Show status
status:
	@echo "Project Status:"
	@echo "==============="
	@if [ -d $(VENV_NAME) ]; then \
		echo "Virtual environment: ✓ Present"; \
		echo "Python version: $$($(PYTHON_VENV) --version)"; \
		echo "Pip version: $$($(PIP) --version)"; \
	else \
		echo "Virtual environment: ✗ Missing"; \
	fi
	@echo "Required files:"
	@for file in main.py config_manager.py transfer_manager.py; do \
		if [ -f $$file ]; then \
			echo "  $$file: ✓"; \
		else \
			echo "  $$file: ✗"; \
		fi; \
	done

# Install system dependencies (Ubuntu/Debian)
system-deps:
	@echo "Installing system dependencies..."
	@if command -v apt-get >/dev/null 2>&1; then \
		sudo apt-get update; \
		sudo apt-get install -y python3 python3-venv python3-pip python3-tk; \
		echo "System dependencies installed ✓"; \
	elif command -v yum >/dev/null 2>&1; then \
		sudo yum install -y python3 python3-venv python3-pip python3-tkinter; \
		echo "System dependencies installed ✓"; \
	elif command -v dnf >/dev/null 2>&1; then \
		sudo dnf install -y python3 python3-venv python3-pip python3-tkinter; \
		echo "System dependencies installed ✓"; \
	else \
		echo "Please install Python 3, venv, and tkinter manually"; \
	fi