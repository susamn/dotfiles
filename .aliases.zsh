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
fi

if [ -x "$(command -v bat)" ]; then
  alias cat="bat"
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
    alias gs='git status'
    alias gd='git diff'
    alias gco='git checkout'
    alias gc='git commit'
    alias gcm='git commit -m'
    alias gca='git commit --amend'
    alias gl='git log'
    alias glo='git log --oneline'
    alias glog='git log --oneline --graph --decorate'
    alias gbl='git blame'
    alias gcl='git clone'
    alias gp='git pull'
    alias gpom='git pull origin main'
    alias gpob='git pull origin $(git rev-parse --abbrev-ref HEAD)'
    alias gph='git push'
    alias gb='git branch'
    alias gnew='git checkout -b'
    alias gm='git merge'
    alias grb='git rebase'
    alias gsh='git stash'
    alias gclean='git clean -fd'
    alias gt='git tag'
    alias gcfg='git config'
    alias gitb='f() {
          remote=$(git config --get remote.origin.url);
          url=$(echo "$remote" | sed -E "s#(git@|https://)([^:/]+)[:/]([^ ]+)#https://\\2/\\3#" | sed "s/\\.git$//");
          branch=$(git rev-parse --abbrev-ref HEAD);
          if echo "$url" | grep -q "github.com"; then
            final_url="$url/tree/$branch"
          elif echo "$url" | grep -q "gitlab.com"; then
            final_url="$url/-/tree/$branch"
          elif echo "$url" | grep -q "bitbucket.org"; then
            final_url="$url/src/$branch"
          else
            final_url="$url/tree/$branch"
          fi
          echo "$final_url";
          if command -v xdg-open > /dev/null; then
            xdg-open "$final_url"
          elif command -v open > /dev/null; then
            open "$final_url"
          elif command -v start > /dev/null; then
            start "$final_url"
          else
            echo "No compatible browser open command found."
          fi
        }; f'
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
