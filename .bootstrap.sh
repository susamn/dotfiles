export WORKSPACE_PATH=~/workspace
mkdir -p $WORKSPACE_PATH/sdk $WORKSPACE_PATH/scripts $WORKSPACE_PATH/install $WORKSPACE_PATH/tools $WORKSPACE_PATH/services $WORKSPACE_PATH/sdk/repositories
source $WORKSPACE_PATH/.variables.sh
source $WORKSPACE_PATH/.aliases.sh
source $WORKSPACE_PATH/.paths.sh
source $WORKSPACE_PATH/.linux.aliases.sh
source $WORKSPACE_PATH/.distro.aliases.sh

HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt appendhistory
# Ctrl + Backspace to delete an entire word
bindkey '^H' backward-kill-word
