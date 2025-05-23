#! /bin/sh

#
# Prelude to be placed at top of each script. Rerun this script either in
# bash or zsh, if not already running in either (which can happen!)
# Allows script to run on systems that either have bash (linux) or
# zsh (macOS) only
#
if [ "$1" != --no-auto-shell ]
then
   if [ -z "${BASH_VERSION}" -a -z "${ZSH_VERSION}" ]
   then
      exe_shell="`command -v "bash" `"
      exe_shell="${exe_shell:-`command -v "zsh" `}"

      script="$0"

      #
      # Quote incoming arguments for shell expansion
      #
      args=""
      for arg in "$@"
      do
         # True Bourne sh doesn't know ${a//b/c} and <<<
         case "${arg}" in
            *\'*)
               # Use cat instead of echo to avoid possible echo -n
               # problems. Escape single quotes in string.
               arg="`cat <<EOF | sed -e s/\'/\'\\\"\'\\\"\'/g
${arg}
EOF
`"
            ;;
         esac
         if [ -z "${args}" ]
         then
            args="'${arg}'"
         else
            args="${args} '${arg}'"
         fi
      done

      #
      # bash/zsh will use arg after -c <arg> as $0, convenient!
      #

      exec "${exe_shell:-bash}" -c ". ${script} --no-auto-shell ${args}" "${script}"
   fi
else
   shift    # get rid of --no-auto-shell
fi
