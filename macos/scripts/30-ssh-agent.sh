# ssh keys. No agent to bootstrap, unlike the Linux side: launchd runs one and
# sets SSH_AUTH_SOCK in every login session. What macOS needs instead is the
# key back in it after a reboot -- --apple-use-keychain is the one-time path
# that stores the passphrase, --apple-load-keychain the one that reuses it.
if ! ssh-add -l >/dev/null 2>&1; then
    ssh-add --apple-load-keychain 2>/dev/null \
        || ssh-add --apple-use-keychain "$HOME/.ssh/id_ed25519" 2>/dev/null
fi
