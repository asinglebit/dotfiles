# dotfiles

Shell, toolchain and terminal config, versioned here and symlinked into `$HOME`.
The repo holds the real files; the OS only references them.

Portable by design — everything here is meant to work on a Linux box and a Mac,
so anything that is genuinely tied to one of them lives under that OS's
directory rather than being branched on inside a shared file.

## Install

```sh
git clone git@github.com:asinglebit/dotfiles.git ~/projects/personal/dotfiles
cd ~/projects/personal/dotfiles
./install.sh --dry-run    # see what it would do
./install.sh
```

Idempotent. Anything it would overwrite is moved to `<name>.bak-<timestamp>`
first. It links per *file*, never per directory, so a tree like `~/.config/tmux`
can hold both our `tmux.conf` and TPM's `plugins/` without one clobbering the
other.

One step it cannot do for you, because it needs a secret typed in:

```sh
secret-tool store --label='ssh key passphrase (id_ed25519)' \
    dotfiles ssh-passphrase key id_ed25519
```

That puts the ssh key's passphrase in the login keyring, where
`ssh-add-key.service` reads it at login so nothing ever has to ask. `install.sh`
prints the same command as a `todo` until it has been done, and `ssh-add -l`
after the next login is the check.

## Layout

| Path | What it does |
| --- | --- |
| `install.sh` | Detects the OS via `uname -s`, links `shared/` plus `linux/` or `macos/`, then enables the systemd user units |
| `linux/.bashrc` | → `~/.bashrc`. Sources `/etc/bashrc`, then `linux/scripts/*.sh` in order |
| `linux/.bash_profile` | → `~/.bash_profile`. Login shells; adds mise's **shims** activation |
| `linux/scripts/` | The pieces `.bashrc` runs, numbered to fix the order |
| `linux/config/ghostty/config` | → `~/.config/ghostty/config`. Currently Sway/GTK-tuned |
| `linux/config/environment.d/10-ssh-agent.conf` | → `~/.config/environment.d/`. `SSH_AUTH_SOCK` for everything in the session that is not a shell |
| `linux/config/systemd/user/ssh-add-key.service` | → `~/.config/systemd/user/`. Loads the ssh key into the agent at login, passphrase from the keyring |
| `linux/ssh/config` | → `~/.ssh/config`. `AddKeysToAgent yes`, and the identity this box signs with |
| `linux/ssh/askpass-keyring` | → `~/.ssh/askpass-keyring`. The `SSH_ASKPASS` helper that unit answers with |
| `linux/share/applications/` | → `~/.local/share/applications/`. Desktop entries for Blender, Godot and the Pay Per Paper project |
| `linux/share/icons/` | → `~/.local/share/icons/`. The Blender and Godot app icons those entries name |
| `macos/.zshrc` | → `~/.zshrc`. Same shape as the Linux side: a loader over `macos/scripts/*.sh` |
| `macos/.zprofile` | → `~/.zprofile`. Login shells; adds mise's **shims** activation |
| `macos/scripts/` | Darwin equivalents. Untested — there is no Mac yet |
| `shared/config/mise/config.toml` | → `~/.config/mise/config.toml`. Tool versions, OS-neutral |
| `shared/config/tmux/tmux.conf` | → `~/.config/tmux/tmux.conf`. XDG path, not `~/.tmux.conf` |

`scripts/` is **not** symlinked into `$HOME`. `.bashrc` locates the repo by
resolving its own symlink and sources them from here, so there is exactly one
copy of each and no second install step to forget.

## Things that are load-bearing, and why

**`90-tmux.sh` has to sort last.** It ends in `tmux attach … && exit`, so nothing
sourced after it runs in the outer shell. The shell tmux then starts re-sources
`.bashrc` with `$TMUX` set, the autostart block skips, and everything earlier —
`dib()` included — gets defined in that inner shell instead. The `&& exit` is
also deliberate: with `exec`, a tmux that cannot start (an unusable `$TERM` is
the usual cause) leaves no shell behind and the terminal just dies.

**Homebrew is appended to `PATH`, never prepended.** Bazzite's
`/etc/profile.d/brew.sh` strips the `PATH=` line out of `brew shellenv` and
re-adds the prefix at the end, so system binaries keep winning over brew's. A
plain `eval "$(brew shellenv)"` would silently invert that. `00-env.sh` repeats
the append rather than calling `shellenv` — and it has to repeat it at all
because the system file is guarded on `$- == *i*`, so a **non-interactive login
shell**, which is what GUI apps and editors inherit, never gets brew on `PATH`.
mise is itself a brew install, so without that the shims activation in
`.bash_profile` would find no mise and do nothing — the exact case those shims
exist to cover.

**mise is activated twice, on purpose.** `scripts/10-mise.sh` runs
`mise activate bash` for interactive shells, which re-derives `PATH` on every
prompt. `.bash_profile` runs `mise activate bash --shims`, which is what
non-interactive login environments get: a directory of stub executables that
keeps working in a process that never re-runs a shell hook.

**`install.sh` resolves its own location with `pwd -P`.** It records that path
inside every symlink it makes, and on an ostree system `/home` is a symlink to
`var/home` — so plain `pwd` yielded `/home/...` when entered via `~` and
`/var/home/...` otherwise. The two never compare equal, and the idempotence
check silently degraded into backing up and re-linking every file on each run.
`-P` resolves to the physical path from either entry point, which is also what
`.bashrc` already gets from its `readlink -f`.

**The desktop entries name mise's shim by absolute path, never a bare `godot` or
`blender`.** The sway session's `PATH` is `/usr/local/bin:/usr/bin:/usr/local/sbin`:
greetd starts it without a login shell, so `.bash_profile` never runs and the
shims activation above never happens. `Exec=blender` therefore works when you
test it in a terminal and fails silently from the launcher, which is a nasty way
to lose an afternoon. All three entries go through
`$HOME/.local/share/mise/shims/`, which also survives a version bump in a way
`installs/<version>/` does not. Godot must also *be* a host binary: a flatpak one
loads Pay Per Paper's GDExtension under the runtime's older glibc and fails to
resolve it. Blender is a host binary for a different reason — the tarball reaches
the NVIDIA driver directly for OptiX and CUDA, with no
`org.freedesktop.Platform.GL.nvidia-*` extension to keep version-matched against
the host's. That, and the image depending on nothing from this repo, is why these
are user-scope.

**All three entries write `$` as `\\$`, inside double quotes.** The command is
wrapped in `sh -c` so `$HOME` expands at launch rather than baking a username
into a committed file, and the desktop-entry format unescapes once before the
shell sees it. Single quotes are *reserved* by that format, so the inner argument
has to use double quotes, and `godot.desktop` and `blender.desktop` forward `%f`
through the `sh -c "… \\"\\$@\\"" sh %f` idiom. `desktop-file-validate` rejects
every other spelling; run it after any edit.

**There is no rustup setup here, and that is not an omission.** mise's
`core:rust` backend *is* rustup — it reports `~/.cargo/bin` as the tool's bin
path and picks the toolchain by exporting `RUSTUP_TOOLCHAIN`, adopting an
existing `~/.rustup` in place. Sourcing `~/.cargo/env` as well would re-prepend
`~/.cargo/bin` ahead of mise's shims, which is the bug this layout replaced.
`rustup` itself still works normally for components, targets and nightlies.

**The ssh agent is systemd's, and a socket file that exists proves nothing.**
`30-ssh-agent.sh` used to start its own agent and pin the socket to a fixed
symlink at `~/.ssh/ssh_auth_sock`, guarded by `[ ! -S … ]`. `-S` follows the
symlink and `~/.ssh` is persistent storage, so the first dead socket that landed
there outlived a reboot, the guard read it as "socket, nothing to do" forever
after, and every shell exported a path with no agent behind it — while the
`ssh-add` on the next line failed into `2>/dev/null`. Silent: no key, no git, no
error. What replaces it fixes the shape rather than that one instance. The
socket is Fedora's socket-activated `ssh-agent.socket` under
`$XDG_RUNTIME_DIR`, a tmpfs, so no boot can inherit a corpse. Liveness is tested
with `ssh-add -l`, which exits 2 for "cannot reach an agent" and 1 for "reached
one holding no keys" — the only reliable way to tell a live socket from a
leftover file. And an inherited `SSH_AUTH_SOCK` is kept *only if it answers*,
which is what preserves a forwarded agent over `ssh -A` while stepping over the
kind of path that got frozen into `~/.ssh` last time.

**Everything that is not a shell gets the agent from `environment.d`.**
`start-sway(1)` evaluates the `environment.d(5)` generator itself, under
`set -o allexport`, before it sources `/etc/sway/environment` — so
`10-ssh-agent.conf` reaches the compositor and everything it launches, which is
exactly the half of the desktop that never sources `.bashrc`: GUI git clients,
editors, user services. Shells set the same value for themselves, which is what
covers an ssh login or a bare TTY, where no user-manager environment arrives.
`%t` is unit-file syntax and means nothing in that file, hence
`${XDG_RUNTIME_DIR}`, which the generator expands from its own environment.

**The passphrase comes out of the login keyring, for one `ssh-add` only.**
`SSH_ASKPASS` is the only channel `ssh-add` offers for a passphrase — it reads
none from stdin — so unlocking a key without a human takes a program,
`~/.ssh/askpass-keyring`, not a pipe. That helper and `SSH_ASKPASS_REQUIRE=force`
are set **inside `ssh-add-key.service` and nowhere else**: session-wide they
would answer every unrelated host-password prompt with silence from a keyring
that holds no entry for it, turning a prompt a human could have answered into a
failure. `force` is needed at all because `ssh-add` consults an askpass only
when it has no tty *and* `$DISPLAY` is set, and at `default.target` time no
compositor has run. The key file stays encrypted either way; what the keyring
holds is the passphrase, under the login password, unlocked by PAM. The lookup
is keyed on the key's *basename*, never its path, because on an ostree system
`$HOME` is `/home/…` for a shell and `/var/home/…` for systemd: same directory,
two strings, and a keyring attribute is matched as a string. The same trap as
`install.sh`'s `pwd -P`, one layer up.

**The OS directories are self-contained, and that means some duplication.**
`20-aliases.sh`, `40-dib.sh` and `90-tmux.sh` are byte-identical under `linux/`
and `macos/`. That is deliberate: a machine only ever reads one OS directory, so
each one can be understood on its own without cross-referencing a shared tree.
The cost is that a change to `dib()` has to be made twice. If that becomes
annoying, the fix is a `shared/scripts/` sourced before the OS one — but note
`90-tmux.sh` would have to stay per-OS regardless, because it must sort last.

Where the two genuinely differ is worth knowing: `00-env.sh` **prepends** brew on
macOS via `brew shellenv` and **appends** it on Linux (Bazzite's policy), and
`30-ssh-agent.sh` resolves the agent systemd provides on Linux but only reloads
Keychain keys on macOS, where launchd already provides one.

**Machine-local escapes, so nothing has to be committed to be temporary:**
`~/.bashrc.d/*` is sourced last and overrides anything above it, and
`~/.config/mise/config.local.toml` layers above the committed tool list.
