# mise - polyglot runtime manager. Owns go, rust, node and pnpm; see
# shared/config/mise/config.toml for the tool list.
#
# Interactive activation. The login half is `mise activate zsh --shims` in
# ../.zprofile, which is what GUI apps and editors inherit.
#
# As on Linux, there is deliberately no rustup setup beside this: mise's
# core:rust backend IS rustup, and sourcing ~/.cargo/env as well would
# re-prepend ~/.cargo/bin ahead of mise's shims.
if command -v mise >/dev/null 2>&1; then
    eval "$(mise activate zsh)"
fi
