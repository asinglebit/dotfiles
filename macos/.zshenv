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
# to this file, and ~/.cargo/env prepends ~/.cargo/bin to PATH. In a login or
# interactive shell that is harmless -- mise activates afterwards and wins. The
# case it breaks is a non-interactive, non-login zsh: `zsh -c ...`, a GUI app
# spawning a shell, an editor's task runner. Those read this file and nothing
# else, so they get ~/.cargo/bin with no mise shims, and cargo and rustc resolve
# to rustup's default toolchain instead of the one
# shared/config/mise/config.toml pins via RUSTUP_TOOLCHAIN. That is exactly the
# drift the README's rustup note describes, in exactly the environment
# .zprofile's shims activation was added to cover.
#
# Removing the line locally would only work until the next `rustup-init`. Owning
# the file means the next one appends HERE, through the symlink, and a silent
# regression shows up as a git diff instead.
