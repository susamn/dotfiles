---
name: python-generic
description: Universal guidelines, patterns, and best practices for Python development
version: 1.1.0
triggers:
  - "work on python project"
  - "create python script"
  - "python backend"
intent: execution
guardrails:
  - "Never install packages globally; I use pyenv, try to activate the virtual environment called Playground for generic work and install packages there. If you see any existing virtual environment created by me in the current directory, use it."
  - "Prefer using `uv` tool for package management and virtual environment management."
  - "Do not use `print()` for application logs; use the standard `logging` module or structural logging like `structlog`."
  - "Avoid overly broad `except Exception:` blocks without logging the stack trace."
  - "Never commit hardcoded secrets, API keys, or database credentials."
  - "Always check if environment variables `LOCAL_CA_BUNDLE`, `PIP_CACHE_DIR`, and `PYTHON3**_HOME` (e.g., `PYTHON311_HOME`, `PYTHON312_HOME`, `PYTHON313_HOME`) are set. If they are, you must use them for your operations."
tools:
  - bash
interface:
  input:
    task: "string — description of the Python task"
  output:
    status: "string — outcome of the operation"
---
## Python Development Guidelines

### 1. Style & Formatting
- Strictly follow **PEP 8** style guidelines for all code.
- Prefer automated formatters and linters: **Ruff**, **Black**, and **isort**.
- Use modern Python type hinting (PEP 484) for function arguments, variables, and return types. Use `mypy` for static type checking.

### 2. Dependency Management
- Ensure dependencies are declared explicitly.
- Use `pyproject.toml` as the modern standard for project configuration, or `requirements.txt`, `Pipfile`, `poetry` based on existing project setup.
- Always isolate projects using a virtual environment (e.g., `python -m venv venv`).
- Pin dependencies in production environments to ensure deterministic builds.

### 3. Architecture & Project Layout
- Prefer the `src/` layout pattern for better packaging and isolation (e.g., `src/my_package/`).
- Ensure modularity: group logic by domain or feature, avoiding massive "god" files.

### 4. Testing
- Use **pytest** for all unit testing.
- Ensure test files are prefixed with `test_` and reside in a dedicated `tests/` directory at the root level.
- Strive for high test coverage and test edge cases.

### 5. Documentation
- Provide docstrings for all public modules, classes, and functions.
- Use a consistent format such as Google-style docstrings.
- Ensure a descriptive `README.md` is maintained for project setup and execution instructions.

### 6. Logging & Error Handling
- Use the built-in `logging` module or `structlog`. Avoid using `print` statements in production code.
- Create custom exception classes for domain-specific errors.
- Always include context and stack traces when logging caught exceptions in the global exception handler.

### 7. Vulnerability Management
- Regularly scan dependencies for known vulnerabilities using tools like `safety` or `pip-audit`.
- Use static application security testing (SAST) tools like `bandit` to identify security issues in your code.
- Ensure dependencies are kept up-to-date. If using `uv`, periodically run update commands to patch vulnerable transitive dependencies.

### 8. API & Web Development
- Use **FastAPI** as the default framework for building web APIs and **Uvicorn** (or similar ASGI servers) for serving them.
- Use **Pydantic** for data validation, serialization, and settings management.
- For web applications or APIs, always check if an **OpenAPI schema** is available first. If it exists, build the implementation strictly around that contract.
