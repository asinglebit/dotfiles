# Aliases.

alias n='nvim'
alias l='ls -a'

# Two Claude Code identities with separate config, history and auth. The
# wrapper form (rather than exporting CLAUDE_CONFIG_DIR) keeps a plain `claude`
# on the default profile.
alias claude-work='CLAUDE_CONFIG_DIR=$HOME/.claude-work claude'
alias claude-personal='CLAUDE_CONFIG_DIR=$HOME/.claude-personal claude'

# guitar, built out of ~/projects/personal/guitar. Guarded on the binary
# existing: on a fresh clone the release build has not happened yet, and an
# alias pointing at a missing file fails confusingly inside dib()'s tmux panes
# rather than at definition time.
_guitar="$HOME/projects/personal/guitar/target/release/guitar"
[ -x "$_guitar" ] && alias g="$_guitar"
unset _guitar
