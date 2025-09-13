# Ensure tmux is always running
if command -v tmux &> /dev/null \
   && [ -n "$PS1" ] \
   && [[ ! "$TERM" =~ screen ]] \
   && [[ ! "$TERM" =~ tmux ]] \
   && [ -z "$TMUX" ]; then
  tmux a -t default || exec tmux new -s default && exit;
fi
