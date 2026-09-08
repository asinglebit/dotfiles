# Aliases.

alias n='nvim'
alias l='ls -a'

# Wrapper form rather than exporting CLAUDE_CONFIG_DIR, so a plain `claude`
# stays on the default profile.
alias claude-work='CLAUDE_CONFIG_DIR=$HOME/.claude-work claude'
alias claude-personal='CLAUDE_CONFIG_DIR=$HOME/.claude-personal claude'

# Guarded: on a fresh clone the release build has not happened yet, and a
# missing binary fails confusingly inside dib()'s panes rather than here.
_guitar="$HOME/projects/personal/guitar/target/release/guitar"
[ -x "$_guitar" ] && alias g="$_guitar"
unset _guitar
