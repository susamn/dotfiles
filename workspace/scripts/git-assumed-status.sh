#!/bin/bash

# Check if we're in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo "❌ Not a git repository"
    exit 1
fi

# Get git root directory
GIT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
if [[ -z "$GIT_ROOT" ]]; then
    GIT_ROOT=$(git rev-parse --git-dir 2>/dev/null)
fi

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'
GRAY='\033[0;90m'
LIGHT_GRAY='\033[1;37m'
LIGHT_GREEN='\033[1;32m'
LIGHT_YELLOW='\033[1;33m'
LIGHT_RED='\033[1;31m'

# Parse flags
show_modified=false
show_new=false
show_staged=false
show_worktree=false
filter_mode=false

usage() {
    echo "Usage: $(basename "$0") [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -s, --staged               Show only staged files"
    echo "  -m, --modified, --updated   Show only updated (modified) files"
    echo "  -w, --worktree             Show only worktree status"
    echo "  -n, --new, --untracked     Show only untracked files"
    echo "  -h, --help                 Show this help message"
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            usage
            ;;
        -m|--modified|--updated)
            show_modified=true
            filter_mode=true
            shift
            ;;
        -n|--new|-u|--untracked)
            show_new=true
            filter_mode=true
            shift
            ;;
        -s|--staged)
            show_staged=true
            filter_mode=true
            shift
            ;;
        -w|--worktree|--worktrees)
            show_worktree=true
            filter_mode=true
            shift
            ;;
        -[!-]* )
            flags="${1#-}"
            for (( i=0; i<${#flags}; i++ )); do
                case "${flags:$i:1}" in
                    m) show_modified=true; filter_mode=true ;;
                    n|u) show_new=true; filter_mode=true ;;
                    s) show_staged=true; filter_mode=true ;;
                    w) show_worktree=true; filter_mode=true ;;
                    h) usage ;;
                    *) echo "Unknown option: -${flags:$i:1}" >&2; exit 1 ;;
                esac
            done
            shift
            ;;
        *)
            echo "Unknown option: $1" >&2
            echo "Use -h or --help for usage." >&2
            exit 1
            ;;
    esac
done

if ! $filter_mode; then
    show_modified=true
    show_new=true
    show_staged=true
    show_worktree=true
    show_assumed=true
else
    show_assumed=false
fi

# Regular git status

# Get branch info
branch_info=$(git status -sb 2>/dev/null | head -1)
echo -e "${MAGENTA}🌿 Branch:${NC} ${branch_info}"
echo

# Only query file statuses if at least one file category is active
if $show_staged || $show_modified || $show_new; then
    staged_files=()
    modified_files=()
    untracked_files=()

    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        status_code="${line:0:2}"
        file_path="${line:3}"

        # Check if path is a submodule
        is_submodule=""
        if [[ -f "${GIT_ROOT}/.gitmodules" ]] && grep -q "path = $file_path" "${GIT_ROOT}/.gitmodules" 2>/dev/null; then
            is_submodule=" 📦"
        fi

        x="${status_code:0:1}"
        y="${status_code:1:1}"

        if [[ "$status_code" == "??" ]]; then
            untracked_files+=("$file_path$is_submodule")
        else
            if [[ "$x" =~ [MADRC] ]]; then
                staged_files+=("$file_path$is_submodule")
            fi
            if [[ "$y" =~ [MDm] || "$status_code" =~ ^(UU|AA|DD)$ ]]; then
                modified_files+=("$file_path$is_submodule")
            fi
        fi
    done < <(git status --porcelain 2>/dev/null)
fi

# 1. Display staged files
if $show_staged; then
    if [[ ${#staged_files[@]} -gt 0 ]]; then
        echo -e "${CYAN}\033[4mStaged\033[0m${NC}"
        for file in "${staged_files[@]}"; do
            echo -e "  ${LIGHT_GREEN}• ${file}${NC}"
        done
        echo
    elif $filter_mode; then
        echo -e "${CYAN}\033[4mStaged\033[0m${NC}"
        echo -e "  ${GREEN}✓ No staged files${NC}"
        echo
    fi
fi

# 2. Display updated files
if $show_modified; then
    if [[ ${#modified_files[@]} -gt 0 ]]; then
        echo -e "${CYAN}\033[4mUpdated\033[0m${NC}"
        for file in "${modified_files[@]}"; do
            echo -e "  ${LIGHT_YELLOW}• ${file}${NC}"

            # If it's a submodule, show commit diff or dirty status
            if [[ "$file" == *"📦" ]]; then
                actual_path="${file% 📦}"
                actual_full_path="${GIT_ROOT}/${actual_path}"

                if [[ -d "$actual_full_path" ]]; then
                    current_commit=$(git -C "$actual_full_path" rev-parse HEAD 2>/dev/null | cut -c1-8)
                    expected_commit=$(git -C "$GIT_ROOT" ls-files -s "$actual_path" 2>/dev/null | awk '{print substr($2,1,8)}')

                    if [[ -n "$current_commit" ]] && [[ -n "$expected_commit" ]]; then
                        if [[ "$current_commit" != "$expected_commit" ]]; then
                            echo -e "     ${GREEN}└─${NC} ${expected_commit} ${CYAN}→${NC} ${MAGENTA}${current_commit}${NC}"
                        else
                            if ! git -C "$actual_full_path" diff --quiet 2>/dev/null || ! git -C "$actual_full_path" diff --cached --quiet 2>/dev/null; then
                                changes=$(git -C "$actual_full_path" status --porcelain 2>/dev/null | wc -l | tr -d ' ')
                                echo -e "     ${GREEN}└─${NC} ${GRAY}(${changes} uncommitted changes)${NC}"
                            fi
                        fi
                    fi
                fi
            fi
        done
        echo
    elif $filter_mode; then
        echo -e "${CYAN}\033[4mUpdated\033[0m${NC}"
        echo -e "  ${GREEN}✓ No updated files${NC}"
        echo
    fi
fi

# 3. Worktree statuses
if $show_worktree; then
    declare -a wt_paths=()
    declare -a wt_heads=()
    declare -a wt_branches=()
    declare -a wt_lockeds=()
    declare -a wt_prunables=()

    cur_path="" cur_head="" cur_branch="" cur_locked="" cur_prunable=""

    commit_wt_record() {
        if [[ -n "$cur_path" ]]; then
            wt_paths+=("$cur_path")
            wt_heads+=("$cur_head")
            wt_branches+=("$cur_branch")
            wt_lockeds+=("$cur_locked")
            wt_prunables+=("$cur_prunable")
        fi
        cur_path="" cur_head="" cur_branch="" cur_locked="" cur_prunable=""
    }

    while IFS= read -r line || [[ -n "$line" ]]; do
        if [[ "$line" =~ ^worktree\ (.*) ]]; then
            commit_wt_record
            cur_path="${BASH_REMATCH[1]}"
        elif [[ "$line" =~ ^HEAD\ (.*) ]]; then
            cur_head="${BASH_REMATCH[1]}"
        elif [[ "$line" =~ ^branch\ (.*) ]]; then
            cur_branch="${BASH_REMATCH[1]}"
        elif [[ "$line" =~ ^locked(.*) ]]; then
            cur_locked="locked"
        elif [[ "$line" =~ ^prunable(.*) ]]; then
            cur_prunable="prunable"
        elif [[ -z "$line" ]]; then
            commit_wt_record
        fi
    done < <(git worktree list --porcelain 2>/dev/null)
    commit_wt_record

    if [[ ${#wt_paths[@]} -gt 0 ]]; then
        echo -e "${CYAN}\033[4mWorktree\033[0m${NC}"
        for i in "${!wt_paths[@]}"; do
            p="${wt_paths[$i]}"
            h="${wt_heads[$i]}"
            b="${wt_branches[$i]}"
            l="${wt_lockeds[$i]}"
            pr="${wt_prunables[$i]}"

            disp_p="${p/#$HOME/\~}"
            branch_name="${b#refs/heads/}"
            [[ -z "$branch_name" ]] && branch_name="detached"
            short_head="${h:0:8}"

            is_curr=false
            [[ "$p" == "$GIT_ROOT" ]] && is_curr=true

            extra=""
            [[ -n "$l" ]] && extra+=" ${RED}🔒 locked${NC}"
            [[ -n "$pr" ]] && extra+=" ${RED}⚠️ prunable${NC}"

            status_detail=""
            if [[ -d "$p" ]]; then
                changes=$(git -C "$p" status --porcelain 2>/dev/null | wc -l | tr -d ' ')
                if [[ $changes -eq 0 ]]; then
                    status_detail="${GRAY}(clean)${NC}"
                else
                    status_detail="${YELLOW}(${changes} uncommitted changes)${NC}"
                fi
            else
                status_detail="${RED}(missing directory)${NC}"
            fi

            if $is_curr; then
                echo -e "  ${LIGHT_GREEN}• ${disp_p}${NC} ${CYAN}[${branch_name}]${NC} ${MAGENTA}(current)${NC}${extra}"
            else
                echo -e "  ${BLUE}• ${disp_p}${NC} ${CYAN}[${branch_name}]${NC}${extra}"
            fi
            echo -e "     ${GREEN}└─${NC} ${short_head} ${status_detail}"
        done
        echo
    elif $filter_mode; then
        echo -e "${CYAN}\033[4mWorktree\033[0m${NC}"
        echo -e "  ${GRAY}No worktrees found${NC}"
        echo
    fi
fi

# 4. Display untracked files
if $show_new; then
    if [[ ${#untracked_files[@]} -gt 0 ]]; then
        echo -e "${CYAN}\033[4mUntracked\033[0m${NC}"
        for file in "${untracked_files[@]}"; do
            echo -e "  ${LIGHT_RED}• ${file}${NC}"
        done
        echo
    elif $filter_mode; then
        echo -e "${CYAN}\033[4mUntracked\033[0m${NC}"
        echo -e "  ${GREEN}✓ No untracked files${NC}"
        echo
    fi
fi

# If working tree is clean in default view
if ! $filter_mode; then
    if [[ ${#staged_files[@]} -eq 0 ]] && [[ ${#modified_files[@]} -eq 0 ]] && [[ ${#untracked_files[@]} -eq 0 ]]; then
        echo -e "  ${GREEN}✓ Working tree clean${NC}"
        echo
    fi
fi

# Check for assumed-unchanged files (only in full view)
if $show_assumed; then
    assumed_files=$(git ls-files -v 2>/dev/null | grep '^[a-z]' | cut -c3-)

    if [[ -n "$assumed_files" ]]; then
        echo -e "${CYAN}\033[4mAssumed-Unchanged\033[0m${NC}"

        while IFS= read -r file; do
            [[ -z "$file" ]] && continue
            git update-index --no-assume-unchanged "$file" 2>/dev/null

            is_submodule=""
            if [[ -f "${GIT_ROOT}/.gitmodules" ]] && grep -q "path = $file" "${GIT_ROOT}/.gitmodules" 2>/dev/null; then
                is_submodule=" 📦"
            fi

            echo -e "  ${LIGHT_GRAY}• ${file}${is_submodule}${NC}"
            git update-index --assume-unchanged "$file" 2>/dev/null
        done <<< "$assumed_files"
        echo
    fi
fi
