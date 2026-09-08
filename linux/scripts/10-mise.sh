# mise -- owns go, rust, node and pnpm; see shared/config/mise/config.toml.
#
# Interactive activation, which re-derives PATH on every prompt. The login half
# is `mise activate bash --shims` in ../.bash_profile.
if command -v mise >/dev/null 2>&1; then
    eval "$(mise activate bash)"
fi
