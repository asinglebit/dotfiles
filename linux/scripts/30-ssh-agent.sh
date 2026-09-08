# One agent per login session, at Fedora's socket-activated ssh-agent.socket
# under $XDG_RUNTIME_DIR -- a tmpfs, so no boot inherits a dead socket the way
# the old ~/.ssh/ssh_auth_sock symlink did.
#
# `ssh-add -l` exits 2 for "no agent" and 1 for "agent, no keys": the only way
# to tell a live socket from a leftover file.
_ssh_agent_live() {
    [ -S "$1" ] || return 1
    SSH_AUTH_SOCK="$1" ssh-add -l >/dev/null 2>&1
    [ "$?" != 2 ]
}

_ssh_sock="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/ssh-agent.socket"

if _ssh_agent_live "${SSH_AUTH_SOCK:-}"; then
    # Inherited one that answers -- a forwarded agent over `ssh -A`, say.
    :
elif _ssh_agent_live "$_ssh_sock"; then
    export SSH_AUTH_SOCK="$_ssh_sock"
elif command -v systemctl >/dev/null 2>&1 &&
        systemctl --user start ssh-agent.socket 2>/dev/null &&
        _ssh_agent_live "$_ssh_sock"; then
    export SSH_AUTH_SOCK="$_ssh_sock"
else
    # No systemd user session. Nothing answered above, so anything at that path
    # is dead -- and ssh-agent -a would refuse to bind over it.
    rm -f "$_ssh_sock"
    eval "$(ssh-agent -s -a "$_ssh_sock" 2>/dev/null)" >/dev/null 2>&1 &&
        export SSH_AUTH_SOCK="$_ssh_sock"
fi

unset _ssh_sock
unset -f _ssh_agent_live

# The key is loaded by ssh-add-key.service at login, not here.
