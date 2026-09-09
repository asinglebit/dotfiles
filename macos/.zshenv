# ~/.zshenv -- a symlink to macos/.zshenv in the dotfiles repo.
#
# zsh sources this for EVERY shell, before .zprofile and .zshrc, interactive or
# not. So it must stay side-effect-free: anything that costs time or touches
# PATH here is paid by every `zsh -c` a tool ever runs.
#
# It exists to hold a line, not to add one. rustup's installer appends
#
#     . "$HOME/.cargo/env"
#
# to this file, which puts ~/.cargo/bin ahead of mise's shims in every
# non-interactive zsh. Removing it locally works only until the next
# `rustup-init`; owning the file means the next one appends HERE, through the
# symlink, so the regression shows up as a git diff. The README's ".zshenv
# exists to hold a line" note has the drift it otherwise causes.
