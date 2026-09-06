# ssh keys.
#
# Unlike the Linux side, there is no agent to bootstrap: macOS runs one under
# launchd and sets SSH_AUTH_SOCK in every login session, so spawning our own
# would just orphan the system one. What macOS needs instead is getting the key
# back into that agent after a reboot, which is what the Keychain does.
#
# --apple-load-keychain restores every key already stored in the Keychain.
# --apple-use-keychain is the one-time path: it adds the key AND stores its
# passphrase, so the load above works on the next boot.
if ! ssh-add -l >/dev/null 2>&1; then
    ssh-add --apple-load-keychain 2>/dev/null \
        || ssh-add --apple-use-keychain "$HOME/.ssh/id_ed25519" 2>/dev/null
fi
