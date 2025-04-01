stow -nvt ~ * | grep "existing target" && echo "Conflicts detected! Aborting." && exit 1
stow -vt ~ *
