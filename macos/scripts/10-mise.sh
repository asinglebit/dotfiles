# mise -- owns go, rust, node and pnpm; see shared/config/mise/config.toml.
# Interactive activation; the login half is `--shims` in ../.zprofile.
if command -v mise >/dev/null 2>&1; then
    eval "$(mise activate zsh)"
fi
