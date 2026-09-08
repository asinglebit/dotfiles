# ssh-agent: one per login session, reached at a socket under $XDG_RUNTIME_DIR.
#
# Fedora ships a socket-activated user agent -- ssh-agent.socket listens on
# %t/ssh-agent.socket, which is $XDG_RUNTIME_DIR/ssh-agent.socket, and starts
# ssh-agent.service on the first connection. OpenSSH 10 adopts that listening
# fd through $LISTEN_FDS, so the agent never opens a socket of its own. It is
# the path /etc/xdg/plasma-workspace/env/ssh-agent.sh already exports, and
# install.sh enables the unit.
#
# Two properties matter, and the hand-rolled agent this replaced had neither:
#
#   * The socket lives on a tmpfs, so every boot starts clean. The old scheme
#     kept a ~/.ssh/ssh_auth_sock symlink -- and ~/.ssh is persistent storage.
#     One dead socket left in there outlived a reboot, `[ -S ... ]` follows the
#     symlink and still called it a socket, so the bootstrap was skipped and
#     every shell after that exported a path with no agent behind it. `ssh-add`
#     then failed into /dev/null, silently, forever: no key, no git.
#   * config/environment.d/10-ssh-agent.conf puts the same path in the systemd
#     user environment, which start-sway(1) evaluates before launching the
#     compositor. Shells and everything sway starts -- GUI editors, git
#     clients, user services -- therefore agree on one agent.
#
# Liveness is tested, never existence: `ssh-add -l` exits 2 when it cannot
# reach an agent and 1 when it reaches one holding no keys, which is the only
# reliable way to tell a live socket from a file left behind by a dead one.
_ssh_agent_live() {
    [ -S "$1" ] || return 1
    SSH_AUTH_SOCK="$1" ssh-add -l >/dev/null 2>&1
    [ "$?" != 2 ]
}

_ssh_sock="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/ssh-agent.socket"

if _ssh_agent_live "${SSH_AUTH_SOCK:-}"; then
    # Inherited a working agent: the sway session's, or one forwarded in over
    # `ssh -A`, or a sandbox proxying its own. Never clobber it -- but only
    # after it answers, because trusting an inherited path without asking is
    # how the dead socket above got frozen into ~/.ssh in the first place.
    :
elif _ssh_agent_live "$_ssh_sock"; then
    export SSH_AUTH_SOCK="$_ssh_sock"
elif command -v systemctl >/dev/null 2>&1 &&
        systemctl --user start ssh-agent.socket 2>/dev/null &&
        _ssh_agent_live "$_ssh_sock"; then
    # Unit present but not started yet -- a first shell on a machine where
    # install.sh has run but the session predates it.
    export SSH_AUTH_SOCK="$_ssh_sock"
else
    # No systemd user session at all: a container, or a distro without the
    # unit. Own agent, socket still under the runtime dir so it cannot outlive
    # the boot. The rm is safe here by elimination: nothing answered on that
    # path, so anything sitting there is already dead, and ssh-agent -a refuses
    # to bind over it.
    rm -f "$_ssh_sock"
    eval "$(ssh-agent -s -a "$_ssh_sock" 2>/dev/null)" >/dev/null 2>&1 &&
        export SSH_AUTH_SOCK="$_ssh_sock"
fi

unset _ssh_sock
unset -f _ssh_agent_live

# The key is deliberately not loaded here. `AddKeysToAgent yes` in ssh/config
# adds it the first time something actually reaches for a remote, so the
# passphrase prompt lands on a `git push` you just typed rather than on the
# first shell after every boot -- and it lands on that shell's tty, which a
# prompt fired from a startup file cannot count on having.
