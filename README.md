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

## Layout

| Path | What it does |
| --- | --- |
| `install.sh` | Detects the OS via `uname -s`, then links `shared/` plus `linux/` or `macos/` |
| `linux/.bashrc` | → `~/.bashrc`. Sources `/etc/bashrc`, then `linux/scripts/*.sh` in order |
| `linux/.bash_profile` | → `~/.bash_profile`. Login shells; adds mise's **shims** activation |
| `linux/scripts/` | The pieces `.bashrc` runs, numbered to fix the order |
| `linux/config/ghostty/config` | → `~/.config/ghostty/config`. Currently Sway/GTK-tuned |
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

**There is no rustup setup here, and that is not an omission.** mise's
`core:rust` backend *is* rustup — it reports `~/.cargo/bin` as the tool's bin
path and picks the toolchain by exporting `RUSTUP_TOOLCHAIN`, adopting an
existing `~/.rustup` in place. Sourcing `~/.cargo/env` as well would re-prepend
`~/.cargo/bin` ahead of mise's shims, which is the bug this layout replaced.
`rustup` itself still works normally for components, targets and nightlies.

**The OS directories are self-contained, and that means some duplication.**
`20-aliases.sh`, `40-dib.sh` and `90-tmux.sh` are byte-identical under `linux/`
and `macos/`. That is deliberate: a machine only ever reads one OS directory, so
each one can be understood on its own without cross-referencing a shared tree.
The cost is that a change to `dib()` has to be made twice. If that becomes
annoying, the fix is a `shared/scripts/` sourced before the OS one — but note
`90-tmux.sh` would have to stay per-OS regardless, because it must sort last.

Where the two genuinely differ is worth knowing: `00-env.sh` **prepends** brew on
macOS via `brew shellenv` and **appends** it on Linux (Bazzite's policy), and
`30-ssh-agent.sh` bootstraps an agent on Linux but only loads Keychain keys on
macOS, where launchd already provides one.

**Machine-local escapes, so nothing has to be committed to be temporary:**
`~/.bashrc.d/*` is sourced last and overrides anything above it, and
`~/.config/mise/config.local.toml` layers above the committed tool list.
