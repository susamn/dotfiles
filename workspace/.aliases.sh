# Shell Mode Configuration
# Set SHELL_MODE=ENHANCED to enable system command replacements (bat->cat, nvim->vim, etc.)
# Set SHELL_MODE=NATIVE to use native system commands
: ${SHELL_MODE:=ENHANCED}  # Default to ENHANCED if not set

# Generic aliases
alias cht="$SCRIPTS_PATH/cht.sh"
alias pkgs="$SCRIPTS_PATH/pkg-listing.sh"
alias o="$SCRIPTS_PATH/open.sh"
alias zsht="$SCRIPTS_PATH/zsh-timeline.sh"
alias gsec="$SCRIPTS_PATH/generate-secure-resources.sh"
alias mln="$SCRIPTS_PATH/music-library-normalizer.py"
alias mpdc="$SCRIPTS_PATH/mpd-configurer.sh"
alias mdbk="$SCRIPTS_PATH/mpdtui-db-backup.sh"
alias mtrim="$SCRIPTS_PATH/music-trimmer.sh"
alias agm="$SCRIPTS_PATH/agm.sh"
alias ht2="$TOOLS_PATH/helpful-tools-v2/quick-start.sh"
alias mtui="$TOOLS_PATH/music-management-tui/music-tui.sh"
alias mosiac="$TOOLS_PATH/mosiac/quick-start.sh"
alias pfm="$TOOLS_PATH/performance-manager/quick-start.sh"
alias mtrm="$TOOLS_PATH/media-trimmer/quick-start.sh"
alias att="$TOOLS_PATH/api-testing-tool/quick-start.sh"

# Route ssh through kitty's ssh kitten when running in kitty, so the remote
# host gets the xterm-kitty terminfo entry (without it, remote line editors
# have no kbs/cub1 and backspace appears to insert a space instead of
# deleting). TERM is xterm-kitty only when unmultiplexed -- under tmux/screen
# it becomes tmux-256color, which remote hosts already have, so this no-ops.
# Use "command ssh" to bypass for hosts where the kitten misbehaves
# (-N port-forward-only sessions, restricted/rbash remote shells).
ssh() {
  if [[ $TERM == xterm-kitty ]] && command -v kitten >/dev/null 2>&1; then
    kitten ssh "$@"
  else
    command ssh "$@"
  fi
}

# eww widgets (lyrics scroll + mpd player, see ~/.config/eww/) --
# restart picks up ~/.config/systemd/user/eww.service, eww.yuck, or
# eww.scss changes; reload is lighter (yuck/scss only, no daemon
# restart, but won't pick up a changed unit file).
alias ewwr="systemctl --user restart eww.service"
alias ewwreload="eww reload"
alias ewwlog="journalctl --user -u eww.service -f"
alias ewwst="systemctl --user status eww.service"

# Reopen the mpd player widget on both monitors after a manual "eww
# close" -- matches eww.service's own ExecStartPost invocations exactly
# (see that file for why win-id is required: each instance's close
# button targets itself by that id, not the shared "mpd-player-window"
# name neither open instance actually uses).
mpdwidget() {
  case "$1" in
    open)
      eww open --id mpd-player-screen0 --screen 0 --arg win-id=mpd-player-screen0 mpd-player-window
      eww open --id mpd-player-screen1 --screen 1 --arg win-id=mpd-player-screen1 mpd-player-window
      ;;
    close)
      eww close mpd-player-screen0 mpd-player-screen1
      ;;
    *)
      echo "Usage: mpdwidget open|close"
      ;;
  esac
}

# activate/deactivate must run in this shell (they mutate PATH/PYENV_VERSION),
# so they can't be delegated to pyenv-sync.sh like the other subcommands.
# Needs "eval $(pyenv init -)" in ~/.bashrc for the pyenv() function to exist.
pnv() {
  case "${1:-}" in
    activate|-a)
      if [ -n "$2" ]; then
        pyenv activate "$2"
      elif command -v fzf >/dev/null 2>&1; then
        local selected_env
        selected_env=$(pyenv virtualenvs --bare --skip-aliases | fzf --prompt="Select env> " --height=10 --reverse)
        [ -n "$selected_env" ] && pyenv activate "$selected_env"
      else
        echo "Usage: pnv activate <env_name> (install fzf for interactive selection)"
        return 1
      fi
      ;;
    deactivate|-d)
      pyenv deactivate
      ;;
    *)
      bash "$TOOLS_PATH/pyenv-sync/pyenv-sync.sh" "$@"
      ;;
  esac
}

if [ -d "$TOOLS_PATH/linux-system-manager" ]; then
  alias lsm="$TOOLS_PATH/linux-system-manager/linux-system-manager.sh"
fi


if [ -x "$(command -v yt-dlp)" ]; then
  alias ytd="$SCRIPTS_PATH/ytd.sh"
fi

if [ -x "$(command -v fastfetch)" ]; then
  alias ff="fastfetch" 
fi

if [ -x "$(command -v mpd)" ] && [ -x "$(command -v playerctl)" ] ; then
  alias mp="$SCRIPTS_PATH/media-play-manager.sh"
fi

if [ -x "$(command -v mpdtui)" ]; then
  alias mtx="mpdtui"
  alias mt="mpdtui --mini"
  alias mtp="mpdtui -p"
  alias mtt="mpdtui -t"
fi

if [ -x "$(command -v bat)" ]; then
  if [ "$SHELL_MODE" = "ENHANCED" ]; then
    alias cat="bat -p"
    alias catx="bat -A"
  fi

  if [ -x "$(command -v batman)" ] && [ "$SHELL_MODE" = "ENHANCED" ]; then
    alias man="batman"
  fi
fi

if [ -x "$(command -v zoxide)" ]; then
  __zoxide_shell="zsh"
  [ -n "$BASH_VERSION" ] && __zoxide_shell="bash"
  if [ "$SHELL_MODE" = "ENHANCED" ]; then
    eval "$(zoxide init "$__zoxide_shell" --cmd cd)"  # Replace 'cd' with zoxide
  else
    eval "$(zoxide init "$__zoxide_shell")"           # Keep 'z' command, preserve native 'cd'
  fi
  unset __zoxide_shell
fi

if [ -x "$(command -v colorls)" ]; then
  if [ "$SHELL_MODE" = "ENHANCED" ]; then
    alias ls="colorls"
    alias lsrt="colorls -alrt"
  fi
fi

if [ -x "$(command -v lazygit)" ]; then
  alias lg="lazygit"
fi

if [ -x "$(command -v lsd)" ]; then
  if [ "$SHELL_MODE" = "ENHANCED" ]; then
    alias ls="lsd"
    alias lsrt="lsd -alrt"
  fi
  alias lstree="lsd --tree"  # Keep lstree as it's a new command, not a replacement
fi

if [ -x "$(command -v eza)" ]; then
  EZA_COMMON_ARGS="-lh --group-directories-first --icons=auto"
  if [ "$SHELL_MODE" = "ENHANCED" ]; then
    alias ls="eza $EZA_COMMON_ARGS"
    alias lsrt="eza $EZA_COMMON_ARGS -a -r -s modified"
  fi
  alias lstree="eza $EZA_COMMON_ARGS --tree"  # Keep lstree as it's a new command, not a replacement
fi

if [ -x "$(command -v jq)" ]; then
  alias jwtd="$SCRIPTS_PATH/jwtd.sh"
fi


if [ -x "$(command -v xsel)" ]; then
  alias pbcopy='xsel --clipboard --input'
  alias pbpaste='xsel --clipboard --output'
fi

if [ -x "$(command -v nvim)" ]; then
  if [ "$SHELL_MODE" = "ENHANCED" ]; then
    alias vi="nvim"
    alias vim="nvim"
  fi
fi

# fzf aliases
if [ -x "$(command -v fzf)" ]; then
  if [ -n "$BASH_VERSION" ]; then
    source <(fzf --bash)
  else
    source <(fzf --zsh)
  fi
  alias fze="fzf --exact"
  alias _als_script="$SCRIPTS_PATH/als.sh"
  alias als="alias|_als_script -m"
  alias rclc="$SCRIPTS_PATH/rclone-config-manager.sh"
  if [ -x "$(command -v fd)" ]; then
    alias ff="$SCRIPTS_PATH/ffo.sh"
    alias ffo="$SCRIPTS_PATH/ffo.sh -o"
    alias uff="$SCRIPTS_PATH/uff.sh"
    alias uffo="$SCRIPTS_PATH/uff.sh -o"
  fi
fi

# git aliases
if [ -x "$(command -v git)" ]; then
    alias g='git'
    alias gadd='git add'
    alias gaa='git add .'
    alias gs="$SCRIPTS_PATH/git-assumed-status.sh"
    alias gdiff='git diff'
    alias gco='git checkout'
    alias gc='git commit'
    alias gcom='git commit -m'
    alias gcm='git checkout $(git_main_branch)'
    alias gca='git commit --amend'
    alias gl='git log'
    alias glo='git log --oneline'
    alias glog='git log --oneline --graph --decorate'
    alias gbl='git blame'
    alias gcl='git clone'
    alias gp='git pull'
    alias gpull='git pull origin $(git rev-parse --abbrev-ref HEAD)'
    alias gpush='git push origin $(git rev-parse --abbrev-ref HEAD)'
    alias gswm='git switch main'
    alias gph='git push'
    alias gb='git branch'
    alias gnew='git checkout -b'
    alias gm='git merge'
    alias grb='git rebase'
    alias gsh="$SCRIPTS_PATH/git-stash-manager.sh"
    alias gsha="$SCRIPTS_PATH/git-stash-apply-current.sh"
    alias gshap="$SCRIPT_PATH/git-stash-apply-current.sh -p"
    alias gclean='git clean -fd'
    alias gt='git tag'
    alias gcfg='git config'
    alias gupdate='git stash && git switch main && git pull origin main && git switch - && git merge main && git stash apply'
    alias gitb="$SCRIPTS_PATH/gitb.sh"
    alias ghr="$SCRIPTS_PATH/git-hard-reset.sh"
    alias gch="$SCRIPTS_PATH/gch.sh"
    alias gassume='git update-index --assume-unchanged'
    alias gunassume='git update-index --no-assume-unchanged'
    alias gassumed="git ls-files -v | grep '^[a-z]'"
    alias gsub='git submodule'
    alias gsubi='git submodule init'
    alias gsubu='git submodule update --init --recursive'
    alias gsubs='git submodule sync --recursive'
    alias gsubst='git submodule status --recursive'
fi

# kubernates aliases
if [ -x "$(command -v kubectl)" ]; then
    alias k='kubectl'
    alias kget='kubectl get'
    alias kgp='kubectl get pods'
    alias kgn='kubectl get nodes'
    alias kga='kubectl get all'
    alias kdesc='kubectl describe'
    alias kexec='kubectl exec -it'
    alias kap='kubectl apply -f'
    alias klog='kubectl logs -f'
    alias kns='kubectl config set-context --current --namespace'
fi
if [ -x "$(command -v minikube)" ]; then
  alias mk="minikube"
fi


if [ -x "$(command -v gh)" ]; then
  alias grev="$SCRIPTS_PATH/pr-review-gen.sh"
fi


if [ -x "$(command -v mvn)" ]; then
  alias mvn_sort="mvn com.github.ekryd.sortpom:sortpom-maven-plugin:2.15.0:sort \
        -Dsort.createBackupFile=false \
        -Dsort.nrOfIndentSpace=1 \
        -Dsort.predefinedSortOrder=custom_1 \
        -Dsort.sortDependencies='groupId,artifactId,scope' \
        -Dsort.sortPlugins='groupId,artifactId,scope' \
        -Dsort.sortProperties=true"
fi


# Walk upward to find project root + environment type
find_project_env() {
    local dir="$PWD"

    while [ "$dir" != "/" ]; do
        # 1. Check common venv folders
        for name in ".venv" ".virtualenv" ".env"; do
            if [ -x "$dir/$name/bin/python" ]; then
                echo "venv:$dir/$name"
                return 0
            fi
        done

        # 2. Poetry project
        if [ -f "$dir/pyproject.toml" ] && command -v poetry >/dev/null 2>&1; then
            echo "poetry:$dir"
            return 0
        fi

        # 3. Pipenv project
        if [ -f "$dir/Pipfile" ] && command -v pipenv >/dev/null 2>&1; then
            echo "pipenv:$dir"
            return 0
        fi

        dir="$(dirname "$dir")"
    done

    return 1
}

# Python runner
py() {
    local result type path
    result=$(find_project_env)

    if [ -n "$result" ]; then
        type="${result%%:*}"
        path="${result#*:}"

        case "$type" in
            venv)
                "$path/bin/python" "$@"
                ;;
            poetry)
                (cd "$path" && poetry run python "$@")
                ;;
            pipenv)
                (cd "$path" && pipenv run python "$@")
                ;;
        esac
    else
        python "$@"
    fi
}

# Pip runner
pyp() {
    local result type path
    result=$(find_project_env)

    if [ -n "$result" ]; then
        type="${result%%:*}"
        path="${result#*:}"

        case "$type" in
            venv)
                "$path/bin/pip" "$@"
                ;;
            poetry)
                (cd "$path" && poetry run pip "$@")
                ;;
            pipenv)
                (cd "$path" && pipenv run pip "$@")
                ;;
        esac
    else
        pip "$@"
    fi
}

# yazi with cd-on-exit: `q` leaves the shell where yazi was, `Q` keeps the
# original cwd. Upstream's recommended wrapper -- yazi itself cannot chdir the
# parent shell, so it writes the last directory to a temp file on exit.
y() {
  local tmp cwd
  tmp="$(mktemp -t yazi-cwd.XXXXXX)"
  yazi "$@" --cwd-file="$tmp"
  if cwd="$(cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
    builtin cd -- "$cwd" || return
  fi
  rm -f -- "$tmp"
}

alias ypkg="$SCRIPTS_PATH/yazi-pkg.sh"
