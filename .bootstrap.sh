export WORKSPACE_PATH=~/workspace
mkdir -p $WORKSPACE_PATH/sdk $WORKSPACE_PATH/scripts $WORKSPACE_PATH/install 
source $WORKSPACE_PATH/.variables.sh
source $WORKSPACE_PATH/.aliases.sh
#source ~/workspace/.variables.sh

HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt appendhistory

