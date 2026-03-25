export WORKSPACE_PATH=~/workspace
mkdir -p $WORKSPACE_PATH/sdk $WORKSPACE_PATH/scripts $WORKSPACE_PATH/install $WORKSPACE_PATH/tools $WORKSPACE_PATH/services $WORKSPACE_PATH/sdk/repositories
source $WORKSPACE_PATH/.variables.sh
source $WORKSPACE_PATH/.paths.sh
source $WORKSPACE_PATH/.linux.aliases.sh
DISTRO_ALIASES_SCRIPT="$WORKSPACE_PATH/.distro.aliases.sh"
DISTRO_GEN_SCRIPT="$WORKSPACE_PATH/.distro-generated.aliases.sh"

if [ ! -f "$DISTRO_GEN_SCRIPT" ] || [ "$DISTRO_ALIASES_SCRIPT" -nt "$DISTRO_GEN_SCRIPT" ]; then
    bash -c "
      source '$DISTRO_ALIASES_SCRIPT'
      echo '# Auto-generated distro aliases from .distro.aliases.sh' > '$DISTRO_GEN_SCRIPT'
      declare -f _pm_sudo >> '$DISTRO_GEN_SCRIPT'
      alias i r u s q qi qf >> '$DISTRO_GEN_SCRIPT' 2>/dev/null
    "
fi
source "$DISTRO_GEN_SCRIPT"

# Run this script at the end so that all the required aliases and functions are defined
source $WORKSPACE_PATH/.aliases.sh

HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt appendhistory
# Ctrl + Backspace to delete an entire word
bindkey '^H' backward-kill-word
