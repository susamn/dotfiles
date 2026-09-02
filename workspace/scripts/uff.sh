#!/bin/bash

# Script to find files interactively using fd (or find), ripgrep, and fzf.
# Optionally opens the selected file in an editor.

# --- Helper Functions ---

check_command() {
  local quiet="${2:-false}"
  if ! command -v "$1" &> /dev/null; then
    if [ "$quiet" != "true" ]; then
      echo "Error: Command '$1' not found. Please install it to use this script."
    fi
    return 1
  fi
  return 0
}

display_usage() {
  echo "Usage: $0 [options] [search_term]"
  echo "Options:"
  echo "  -o    Open the selected file in \$EDITOR (falls back to vim)."
  echo "  -h    Show this help message."
  echo "  -d    Search for content inside files using ripgrep."
  echo "  -e    Enable exact-match for file search (like fzf -e)."
  echo "  -x    Search for files with a specific extension (with or without leading dot)."
  echo "  -r    Exclude files with the given intermediate path."
  echo "  -i    Include files with the given intermediate path."
  echo "  -s    Perform a case-insensitive search (only works with -d)."
  echo ""
  echo "Examples:"
  echo "  $0 my_file.txt          # Find files with 'my_file.txt' in the name"
  echo "  $0 -e my_file.txt       # Find files with exact name 'my_file.txt'"
  echo "  $0 -x pdf               # Find all PDF files"
  echo "  $0 -o important_doc.md  # Find 'important_doc.md' and open it in \$EDITOR"
  echo "  $0 -d 'some content'    # Find files containing 'some content'"
  echo "  $0 -d 'pattern' -x log  # Find .log files containing 'pattern'"
  echo "  $0 -r 'pkg/mod' -i 'tools' # Exclude 'pkg/mod' and include 'tools'"
}

# --- Main Script ---

OPEN_IN_EDITOR=false
CONTENT_SEARCH=""
EXACT_MATCH=false
EXTENSION_SEARCH=""
EXCLUDE_PATH=""
INCLUDE_PATH=""
CASE_INSENSITIVE=false
FILE_SEARCH_ARGS=()

# Parse command-line arguments
while getopts "ohx:d:er:i:s" opt; do
  case "$opt" in
    o)
      OPEN_IN_EDITOR=true
      ;;
    h)
      display_usage
      exit 0
      ;;
    d)
      CONTENT_SEARCH="$OPTARG"
      ;;
    e)
      EXACT_MATCH=true
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

# Check for required tools (only warn about the fallback if we actually need to fall back)
if check_command "fd" true; then
  FILE_FIND_CMD="fd"
elif check_command "find"; then
  FILE_FIND_CMD="find"
else
  echo "Error: Neither 'fd' nor 'find' command found. Please install either of them."
  exit 1
fi

EDITOR_CMD="${EDITOR:-vim}"
if [ "$OPEN_IN_EDITOR" = true ] && ! check_command "$EDITOR_CMD" true; then
  echo "Warning: editor '$EDITOR_CMD' not found. Falling back to vim."
  EDITOR_CMD="vim"
  if ! check_command "vim" true; then
    echo "Warning: 'vim' not found either. Will not open file automatically."
    OPEN_IN_EDITOR=false
  fi
fi

if ! check_command "fzf"; then
  echo "Error: 'fzf' command not found. Please install it for interactive selection."
  exit 1
fi

# --- File search ---
# search_results holds the current candidate list.
# results_computed tracks whether a real filter/search has run yet, so an
# empty result from a filter is never confused with "nothing ran yet" and
# silently replaced by an unrelated fallback listing.
search_results=""
results_computed=false

if [ -n "$EXTENSION_SEARCH" ]; then
  ext="${EXTENSION_SEARCH#.}"
  if [ "$FILE_FIND_CMD" = "fd" ]; then
    search_results=$(fd -e "$ext" 2>/dev/null)
  else
    search_results=$(find . -iname "*.$ext" -print 2>/dev/null)
  fi
  results_computed=true
elif [ "${#FILE_SEARCH_ARGS[@]}" -gt 0 ]; then
  if [ "$FILE_FIND_CMD" = "fd" ]; then
    if [ "$EXACT_MATCH" = true ]; then
      search_results=$(fd -g "${FILE_SEARCH_ARGS[@]}" 2>/dev/null)
    else
      search_results=$(fd "${FILE_SEARCH_ARGS[@]}" 2>/dev/null)
    fi
  else
    find_expr=()
    for term in "${FILE_SEARCH_ARGS[@]}"; do
      [ "${#find_expr[@]}" -gt 0 ] && find_expr+=(-o)
      if [ "$EXACT_MATCH" = true ]; then
        find_expr+=(-iname "${term}")
      else
        find_expr+=(-iname "*${term}*")
      fi
    done
    search_results=$(find . \( "${find_expr[@]}" \) -print 2>/dev/null)
  fi
  results_computed=true
fi

# Narrow by content if requested. If a name/extension filter already ran,
# only search inside its candidates; if it found nothing, there is nothing
# to content-search. If no name filter ran, content search covers the tree.
if [ -n "$CONTENT_SEARCH" ]; then
  if check_command "rg" true; then
    RG_OPTS=()
    if [ "$CASE_INSENSITIVE" = true ]; then
      RG_OPTS+=(--ignore-case)
    fi
    if [ "$results_computed" = true ]; then
      if [ -n "$search_results" ]; then
        mapfile -t candidate_files <<< "$search_results"
        search_results=$(rg -l "${RG_OPTS[@]}" -- "$CONTENT_SEARCH" "${candidate_files[@]}" 2>/dev/null)
      else
        search_results=""
      fi
    else
      search_results=$(rg -l "${RG_OPTS[@]}" -- "$CONTENT_SEARCH" 2>/dev/null)
      results_computed=true
    fi
  else
    echo "Error: 'ripgrep' command not found. Cannot perform content-based search."
    exit 1
  fi
fi

# Exclude/include filters, applied unconditionally to whatever we have so far
if [ -n "$EXCLUDE_PATH" ] && [ -n "$search_results" ]; then
  search_results=$(printf '%s\n' "$search_results" | grep -v -- "$EXCLUDE_PATH")
fi
if [ -n "$INCLUDE_PATH" ] && [ -n "$search_results" ]; then
  search_results=$(printf '%s\n' "$search_results" | grep -- "$INCLUDE_PATH")
fi

# Only fall back to "list everything" when no search/filter was given at all
if [ "$results_computed" = false ]; then
  if [ "$FILE_FIND_CMD" = "fd" ]; then
    search_results=$(fd 2>/dev/null)
  else
    search_results=$(find . -print 2>/dev/null)
  fi
fi

# Filter results with fzf (with preview panel showing absolute path and file content)
if [ -n "$search_results" ]; then
  export CONTENT_SEARCH
  FZF_OPTS=(--ansi --preview-window='right:60%:wrap')
  [ "$EXACT_MATCH" = true ] && FZF_OPTS+=(-e)

  if [ -n "$CONTENT_SEARCH" ]; then
    selected_file=$(printf '%s\n' "$search_results" | fzf \
      "${FZF_OPTS[@]}" \
      --preview 'echo -e "\033[1;36m{}\033[0m" && echo "" && rg --color=always --heading --line-number --context=3 -- "$CONTENT_SEARCH" {} 2>/dev/null || bat --style=numbers --color=always --line-range=:100 {} 2>/dev/null || cat {} 2>/dev/null')
  else
    selected_file=$(printf '%s\n' "$search_results" | fzf \
      "${FZF_OPTS[@]}" \
      --preview 'echo -e "\033[1;36m{}\033[0m" && echo "" && bat --style=numbers --color=always --line-range=:100 {} 2>/dev/null || cat {} 2>/dev/null')
  fi

  if [ -n "$selected_file" ]; then
    echo "Selected: $selected_file"
    if [ "$OPEN_IN_EDITOR" = true ]; then
      echo "Opening '$selected_file' in $EDITOR_CMD..."
      "$EDITOR_CMD" "$selected_file"
    fi
  fi
else
  echo "No files found matching your criteria."
fi

exit 0
