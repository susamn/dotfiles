---
name: python-generic
description: Universal guidelines, patterns, and best practices for Python development
version: 1.0.0
triggers:
  - "work on python project"
  - "create python script"
  - "python backend"
intent: execution
guardrails:
  - "Never install packages globally; always use a virtual environment (`venv`, `poetry`, `conda`)."
  - "Do not use `print()` for application logs; use the standard `logging` module or structural logging like `structlog`."
  - "Avoid overly broad `except Exception:` blocks without logging the stack trace."
tools:
  - bash
interface:
  input:
    task: "string — description of the Python task"
  output:
    status: "string — outcome of the operation"
---
## Python Development Guidelines

### 1. Style & Typing
- Strictly follow **PEP 8** style guidelines for all code.
- Always use modern Python type hinting (PEP 484) for function arguments, variables, and return types.

### 2. Dependency Management
- Ensure dependencies are declared explicitly.
- Use `requirements.txt`, `Pipfile`, `poetry`, or `pyproject.toml` based on the existing project configuration.
- Do not make changes to the system Python environment.

### 3. Testing
- Use **pytest** for all unit testing.
- Ensure test files are prefixed with `test_` and reside in a dedicated `tests/` directory or alongside the module depending on the project's layout.

### 4. Documentation
- Provide docstrings for all public modules, classes, and functions.
- Use a consistent format such as Google-style or Sphinx-style docstrings.
