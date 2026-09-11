# Aliases -- the Linux half of shared/scripts/20-aliases.sh.

# Pay Per Paper, through its Linux entry point. Guarded so a box without the
# clone keeps `bg` as the job-control builtin instead of a dead alias.
_payperpaper="$HOME/projects/personal/payperpaper/scripts/linux/project.sh"
if [ -x "$_payperpaper" ]; then
    alias bg="$_payperpaper build game debug"
    alias re="$_payperpaper run editor debug"
fi
unset _payperpaper
