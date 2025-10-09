# Generic aliases
alias cht="$SCRIPTS_PATH/cht.sh"
alias pkgs="$SCRIPTS_PATH/pkg-listing.sh"
alias o="$SCRIPTS_PATH/open.sh"
alias gsk="$SCRIPTS_PATH/generate-ssh-keys.sh"
alias ht2="$TOOLS_PATH/helpful-tools-v2/quick-start.sh"
alias pfm="$TOOLS_PATH/performance-manager/quick-start.sh"
alias mt="$TOOLS_PATH/media-trimmer/quick-start.sh"
alias att="$TOOLS_PATH/api-testing-tool/quick-start.sh"

alias pnv="$TOOLS_PATH/pyenv-sync/pyenv-sync.sh"

if [ -f /etc/os-release ] && grep -qi "arch" /etc/os-release; then
  alias abm="$SCRIPTS_PATH/arch-boot-manager.sh"
fi

if [ -x "$(command -v yt-dlp)" ]; then
  alias ytd="$SCRIPTS_PATH/ytd.sh"
fi

if [ -x "$(command -v zoxide)" ]; then
  eval "$(zoxide init zsh)"
  alias cd="z"
fi

if [ -x "$(command -v colorls)" ]; then
  alias ls="colorls"
  alias lsrt="colorls -alrt"
fi

if [ -x "$(command -v lazygit)" ]; then
  alias lg="lazygit"
fi

if [ -x "$(command -v lsd)" ]; then
  alias ls="lsd"
  alias lsrt="lsd -alrt"
  alias lstree="lsd --tree"
fi

if [ -x "$(command -v bat)" ]; then
  alias cat="bat -p"
fi

if [ -x "$(command -v jq)" ]; then
  alias jwtd="$SCRIPTS_PATH/jwtd.sh"
fi


if [ -x "$(command -v xsel)" ]; then
  alias pbcopy='xsel --clipboard --input'
  alias pbpaste='xsel --clipboard --output'
fi

if [ -x "$(command -v nvim)" ]; then
    alias vi="nvim"
    alias vim="nvim"
fi

# fzf aliases
if [ -x "$(command -v fzf)" ]; then
  source <(fzf --zsh)
  alias fze="fzf --exact"
  #alias als="alias|fzf"
  alias _als_script="$SCRIPTS_PATH/als.sh"
  alias als="alias|_als_script -m"
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
    alias ga='git add'
    alias gaa='git add .'
    alias gs="$SCRIPTS_PATH/git-assumed-status.sh"
    alias gd='git diff'
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
    alias gsh='git stash'
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

# Maven aliases
if [ -x "$(command -v mvn)" ]; then
  alias mvn="mvn -s <settings-file-location>"
  alias mvn8="JAVA_HOME=/path/to/java8 mvn -s <settings-file-location>"
  alias mvn_sort="mvn com.github.ekryd.sortpom:sortpom-maven-plugin:2.15.0:sort \
        -Dsort.createBackupFile=false \
        -Dsort.nrOfIndentSpace=1 \
        -Dsort.predefinedSortOrder=custom_1 \
        -Dsort.sortDependencies='groupId,artifactId,scope' \
        -Dsort.sortPlugins='groupId,artifactId,scope' \
        -Dsort.sortProperties=true"
fi

