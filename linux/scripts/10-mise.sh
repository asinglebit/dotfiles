# mise - polyglot runtime manager. Owns go, rust, node and pnpm; see
# shared/config/mise/config.toml for the tool list.
#
# This is the interactive activation, which injects each resolved tool's bin
# directory into PATH and re-derives it on every prompt. The login half lives
# in ../.bash_profile as `mise activate bash --shims`, which is what GUI apps
# and editors inherit -- they never source an interactive rc.
#
# There is deliberately no rustup setup next to this. mise's core:rust backend
# IS rustup: it reports ~/.cargo/bin as the tool's bin path and selects the
# toolchain with RUSTUP_TOOLCHAIN. Sourcing ~/.cargo/env here as well would
# re-prepend ~/.cargo/bin ahead of mise's shims -- which is exactly the bug
# this file set replaced.
if command -v mise >/dev/null 2>&1; then
    eval "$(mise activate bash)"
fi
