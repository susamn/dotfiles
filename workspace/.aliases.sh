# Generic aliases
alias cht="$SCRIPTS_PATH/cht.sh"

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

if [ -x "$(command -v lsd)" ]; then
  alias ls="lsd"
  alias lsrt="lsd -alrt"
  alias lstree="lsd --tree"
fi

if [ -x "$(command -v bat)" ]; then
  alias cat="bat"
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
  alias fze="fzf --exact"
  alias als="alias|fzf"
fi

# git aliases
if [ -x "$(command -v git)" ]; then
    alias g='git'
    alias ga='git add'
    alias gaa='git add .'
    alias gs='git status -sb'
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
fi

