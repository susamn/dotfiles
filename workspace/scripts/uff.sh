#!/bin/bash

# Script to find files interactively using fd (or find), ripgrep, and fzf.
# Optionally opens the selected file in vim.

# --- Helper Functions ---

check_command() {
  if ! command -v "$1" &> /dev/null; then
    echo "Error: Command '$1' not found. Please install it to use this script."
    return 1
  fi
  return 0
}

display_usage() {
  echo "Usage: $0 [options] [search_term]"
  echo "Options:"
  echo "  -o    Open the selected file in vim."
  echo "  -h    Show this help message."
  echo "  -c    Search for content inside files using ripgrep."
  echo "  -e    Search for files with a specific extension."
  echo ""
  echo "Examples:"
  echo "  $0 my_file.txt          # Find files with 'my_file.txt' in the name"
  echo "  $0 -e .pdf              # Find all PDF files"
  echo "  $0 -o important_doc.md  # Find 'important_doc.md' and open it in vim"
  echo "  $0 -c 'some content'    # Find files containing 'some content'"
  echo "  $0 -c 'pattern' -e .log # Find .log files containing 'pattern'"
}

# --- Main Script ---

OPEN_IN_VIM=false
CONTENT_SEARCH=""
EXTENSION_SEARCH=""
FILE_SEARCH_ARGS=()

# Parse command-line arguments
while getopts "ohc:e:" opt; do
  case "$opt" in
    o)
      OPEN_IN_VIM=true
      ;;
    h)
      display_usage
      exit 0
      ;;
    c)
      CONTENT_SEARCH="$OPTARG"
      ;;
    e)
      EXTENSION_SEARCH="$OPTARG"
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      display_usage
      exit 1
      ;;
  esac
done
shift $((OPTIND - 1))

# Remaining arguments are for file name/pattern search
FILE_SEARCH_ARGS=("$@")

# Check for required tools
if check_command "fd"; then
  FILE_FIND_CMD="fd"
elif check_command "find"; then
  FILE_FIND_CMD="find"
else
  echo "Error: Neither 'fd' nor 'find' command found. Please install either of them."
  exit 1
fi

if [ "$OPEN_IN_VIM" = true ] && ! check_command "vim"; then
  OPEN_IN_VIM=false
  echo "Warning: 'vim' not found. Will not open file automatically."
fi

if ! check_command "fzf"; then
  echo "Error: 'fzf' command not found. Please install it for interactive selection."
  exit 1
fi

# Perform file search
search_results=""

if [ -n "$CONTENT_SEARCH" ]; then
  if check_command "rg"; then
    if [ "${#FILE_SEARCH_ARGS[@]}" -gt 0 ]; then
      initial_files=$(fd "${FILE_SEARCH_ARGS[@]}" 2>/dev/null)
      if [ -n "$initial_files" ]; then
        search_results=$(echo "$initial_files" | xargs rg -l -- "$CONTENT_SEARCH" 2>/dev/null)
      fi
    else
      search_results=$(rg -l -- "$CONTENT_SEARCH" 2>/dev/null)
    fi
  else
    echo "Error: 'ripgrep' command not found. Cannot perform content-based search."
    exit 1
  fi
else
  if [ -n "$EXTENSION_SEARCH" ]; then
    if [ "$FILE_FIND_CMD" = "fd" ]; then
      search_results=$(fd -e "$EXTENSION_SEARCH" 2>/dev/null)
    else
      search_results=$(find . -iname "*.$EXTENSION_SEARCH" -print 2>/dev/null)
    fi
  elif [ "${#FILE_SEARCH_ARGS[@]}" -gt 0 ]; then
    if [ "$FILE_FIND_CMD" = "fd" ]; then
      search_results=$(fd "${FILE_SEARCH_ARGS[@]}" 2>/dev/null)
    else
      search_results=$(find . -iname "*${FILE_SEARCH_ARGS[0]}*" -print 2>/dev/null)
    fi
  else
    # Default: list all files in the current directory
    if [ "$FILE_FIND_CMD" = "fd" ]; then
      search_results=$(fd 2>/dev/null)
    else
      search_results=$(find . -print 2>/dev/null)
    fi
  fi
fi

# Filter results with fzf (with preview panel showing absolute path and file content)
if [ -n "$search_results" ]; then
  if [ -n "$CONTENT_SEARCH" ]; then
    selected_file=$(echo "$search_results" | fzf --preview "echo -e '\033[1;32mFile Path: \033[1;37m{}' && echo '------------------------------------' && rg --color=always --context=5 '$CONTENT_SEARCH' {} || bat --style=numbers --color=always --line-range=:100 {}")
  else
    selected_file=$(echo "$search_results" | fzf --preview 'echo -e "\033[1;32mFile Path: \033[1;37m{}"; echo "------------------------------------"; bat --style=numbers --color=always --line-range=:100 {}')
  fi

  if [ -n "$selected_file" ]; then
    echo "Selected: $selected_file"
    if [ "$OPEN_IN_VIM" = true ]; then
      echo "Opening '$selected_file' in vim..."
      vim "$selected_file"
    fi
  fi
else
  echo "No files found matching your criteria."
fi

exit 0

