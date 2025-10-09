#!/bin/bash

# Check if we're in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo "❌ Not a git repository"
    exit 1
fi

# Get git root directory
GIT_ROOT=$(git rev-parse --show-toplevel)

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Regular git status

# Get branch info
branch_info=$(git status -sb | head -1)
echo -e "${MAGENTA}🌿 Branch:${NC} ${branch_info}"
echo

# Get all files and group them
staged_files=()
modified_files=()
untracked_files=()

while IFS= read -r line; do
    status_code="${line:0:2}"
    file_path="${line:3}"

    # Check if path is a submodule
    is_submodule=""
    if [[ -f "${GIT_ROOT}/.gitmodules" ]] && grep -q "path = $file_path" "${GIT_ROOT}/.gitmodules" 2>/dev/null; then
        is_submodule=" 📦"
    fi

    case "$status_code" in
        "M "|"MM"|"A "|"AM"|"D "|"R "|"RM")
            staged_files+=("$file_path$is_submodule")
            ;;
        " M"|" D"|" m"|"UU"|"AA"|"DD")
            modified_files+=("$file_path$is_submodule")
            ;;
        "??")
            untracked_files+=("$file_path$is_submodule")
            ;;
        *)
            modified_files+=("$file_path$is_submodule")
            ;;
    esac
done < <(git status --porcelain)

# Light colors for file listings
LIGHT_GREEN='\033[1;32m'
LIGHT_YELLOW='\033[1;33m'
LIGHT_RED='\033[1;31m'

# Display staged files
if [[ ${#staged_files[@]} -gt 0 ]]; then
    echo -e "${CYAN}\033[4mStaged\033[0m${NC}"
    for file in "${staged_files[@]}"; do
        echo -e "  ${LIGHT_GREEN}• ${file}${NC}"
    done
    echo
fi

# Display modified files
if [[ ${#modified_files[@]} -gt 0 ]]; then
    echo -e "${CYAN}\033[4mModified\033[0m${NC}"
    for file in "${modified_files[@]}"; do
        echo -e "  ${LIGHT_YELLOW}• ${file}${NC}"

        # If it's a submodule, show commit diff or dirty status
        if [[ "$file" == *"📦" ]]; then
            actual_path="${file% 📦}"
            # Use git root relative path
            actual_full_path="${GIT_ROOT}/${actual_path}"

            if [[ -d "$actual_full_path" ]]; then
                # Get current commit in submodule
                current_commit=$(git -C "$actual_full_path" rev-parse HEAD 2>/dev/null | cut -c1-8)
                # Get what's recorded in parent repo's index
                expected_commit=$(git -C "$GIT_ROOT" ls-files -s "$actual_path" 2>/dev/null | awk '{print substr($2,1,8)}')

                if [[ -n "$current_commit" ]] && [[ -n "$expected_commit" ]]; then
                    if [[ "$current_commit" != "$expected_commit" ]]; then
                        # Commit pointer changed
                        echo -e "     ${GREEN}└─${NC} ${expected_commit} ${CYAN}→${NC} ${MAGENTA}${current_commit}${NC}"
                    else
                        # Check if submodule has uncommitted changes
                        if ! git -C "$actual_full_path" diff --quiet 2>/dev/null || ! git -C "$actual_full_path" diff --cached --quiet 2>/dev/null; then
                            # Count changes
                            changes=$(git -C "$actual_full_path" status --porcelain 2>/dev/null | wc -l)
                            echo -e "     ${GREEN}└─${NC} ${GRAY}(${changes} uncommitted changes)${NC}"
                        fi
                    fi
                fi
            fi
        fi
    done
    echo
fi

# Display untracked files
if [[ ${#untracked_files[@]} -gt 0 ]]; then
    echo -e "${CYAN}\033[4mUntracked\033[0m${NC}"
    for file in "${untracked_files[@]}"; do
        echo -e "  ${LIGHT_RED}• ${file}${NC}"
    done
    echo
fi

# If working tree is clean
if [[ ${#staged_files[@]} -eq 0 ]] && [[ ${#modified_files[@]} -eq 0 ]] && [[ ${#untracked_files[@]} -eq 0 ]]; then
    echo -e "  ${GREEN}✓ Working tree clean${NC}"
fi

echo

# Check for assumed-unchanged files
assumed_files=$(git ls-files -v | grep '^[a-z]' | awk '{print $2}')

if [[ -z "$assumed_files" ]]; then
    exit 0
fi

# Gray colors
GRAY='\033[0;90m'
LIGHT_GRAY='\033[1;37m'

# Display assumed-unchanged files
echo -e "${CYAN}\033[4mAssumed-Unchanged\033[0m${NC}"

echo "$assumed_files" | while read -r file; do
    # Temporarily remove assume-unchanged flag
    git update-index --no-assume-unchanged "$file"

    # Check file status
    file_status=$(git status --porcelain -- "$file")

    # Check if path is a submodule
    is_submodule=""
    if [[ -f "${GIT_ROOT}/.gitmodules" ]] && grep -q "path = $file" "${GIT_ROOT}/.gitmodules" 2>/dev/null; then
        is_submodule=" 📦"
    fi

    # Display file in gray
    echo -e "  ${LIGHT_GRAY}• ${file}${is_submodule}${NC}"

    # Restore assume-unchanged flag
    git update-index --assume-unchanged "$file"
done
