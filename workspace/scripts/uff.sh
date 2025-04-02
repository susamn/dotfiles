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
  echo "  -e    Search for content inside files using ripgrep."
  echo "  -x    Search for files with a specific extension."
  echo "  -r    Exclude files with the given intermediate path."
  echo "  -i    Include files with the given intermediate path."
  echo "  -s    Perform a case-insensitive search (only works with -e)."
  echo ""
  echo "Examples:"
  echo "  $0 my_file.txt          # Find files with 'my_file.txt' in the name"
  echo "  $0 -x .pdf              # Find all PDF files"
  echo "  $0 -o important_doc.md  # Find 'important_doc.md' and open it in vim"
  echo "  $0 -e 'some content'    # Find files containing 'some content'"
  echo "  $0 -e 'pattern' -x .log # Find .log files containing 'pattern'"
  echo "  $0 -r 'pkg/mod' -i 'tools' # Exclude 'pkg/mod' and include 'tools'"
}

# --- Main Script ---

OPEN_IN_VIM=false
CONTENT_SEARCH=""
EXTENSION_SEARCH=""
EXCLUDE_PATH=""
INCLUDE_PATH=""
CASE_INSENSITIVE=false
FILE_SEARCH_ARGS=()

# Parse command-line arguments
while getopts "ohx:e:r:i:s" opt; do
  case "$opt" in
    o)
      OPEN_IN_VIM=true
      ;;
    h)
      display_usage
      exit 0
      ;;
    e)
      CONTENT_SEARCH="$OPTARG"
      ;;
    x)
      EXTENSION_SEARCH="$OPTARG"
      ;;
    r)
      EXCLUDE_PATH="$OPTARG"
      ;;
    i)
      INCLUDE_PATH="$OPTARG"
      ;;
    s)
      CASE_INSENSITIVE=true
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

# Perform file search with priority to extension matching
search_results=""

# First, search by extension if provided
if [ -n "$EXTENSION_SEARCH" ]; then
  if [ "$FILE_FIND_CMD" = "fd" ]; then
    search_results=$(fd -e "$EXTENSION_SEARCH" 2>/dev/null)
  else
    search_results=$(find . -iname "*.$EXTENSION_SEARCH" -print 2>/dev/null)
  fi
fi

# Then, search for content if provided
if [ -n "$CONTENT_SEARCH" ]; then
  if check_command "rg"; then
    RG_OPTS=""
    if [ "$CASE_INSENSITIVE" = true ]; then
      RG_OPTS="--ignore-case"
    fi
    if [ -n "$search_results" ]; then
      search_results=$(echo "$search_results" | xargs rg -l $RG_OPTS -- "$CONTENT_SEARCH" 2>/dev/null)
    else
      search_results=$(rg -l $RG_OPTS -- "$CONTENT_SEARCH" 2>/dev/null)
    fi
  else
    echo "Error: 'ripgrep' command not found. Cannot perform content-based search."
    exit 1
  fi
fi

# Exclude files with the given path if -r is provided
if [ -n "$EXCLUDE_PATH" ]; then
  search_results=$(echo "$search_results" | grep -v "$EXCLUDE_PATH")
fi

# Include files with the given path if -i is provided
if [ -n "$INCLUDE_PATH" ]; then
  search_results=$(echo "$search_results" | grep "$INCLUDE_PATH")
fi

# If no extension or content search was applied, fallback to general search
if [ -z "$search_results" ]; then
  if [ "${#FILE_SEARCH_ARGS[@]}" -gt 0 ]; then
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

