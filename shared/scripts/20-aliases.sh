# Aliases.

alias n='nvim'
alias l='ls -a'

# Wrapper form rather than exporting CLAUDE_CONFIG_DIR, so a plain `claude`
# stays on the default profile. --append-system-prompt-file ADDS to the built-in
# prompt; --system-prompt(-file) would replace it and take the tool instructions
# with it. $DOTFILES is exported by .bashrc/.zshrc before this file is sourced,
# and both expand at invocation rather than here.
alias claude-work='CLAUDE_CONFIG_DIR=$HOME/.claude-work claude --append-system-prompt-file "$DOTFILES/shared/prompts/system-prompt.md"'
alias claude-personal='CLAUDE_CONFIG_DIR=$HOME/.claude-personal claude --append-system-prompt-file "$DOTFILES/shared/prompts/system-prompt.md"'

# Guarded: on a fresh clone the release build has not happened yet, and a
# missing binary fails confusingly inside dib()'s panes rather than here.
_guitar="$HOME/projects/personal/guitar/target/release/guitar"
[ -x "$_guitar" ] && alias g="$_guitar"
unset _guitar
