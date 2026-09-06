# PATH.

# ~/.local/bin carries claude and other user-installed binaries; ~/bin is the
# traditional spot. Guarded so re-sourcing does not stack duplicate entries.
case ":$PATH:" in
    *":$HOME/.local/bin:"*) ;;
    *) PATH="$HOME/.local/bin:$HOME/bin:$PATH" ;;
esac

# Homebrew, APPENDED -- never `eval "$(brew shellenv)"`.
#
# Bazzite's /etc/profile.d/brew.sh deliberately strips the `PATH=` line out of
# `brew shellenv` and re-adds the prefix at the END, so system binaries keep
# winning over brew's (the ublue-os comment cites dbus). A plain shellenv here
# would prepend and silently invert that.
#
# It is repeated here because that system file is guarded on `$- == *i*`, so a
# NON-interactive login shell -- which is what GUI apps and editors inherit --
# never gets brew on PATH at all. mise itself is a brew install, so without
# this the `mise activate --shims` in ../.bash_profile finds no mise and
# silently does nothing, which is the exact case those shims exist to cover.
if [ -d /home/linuxbrew/.linuxbrew/bin ]; then
    case ":$PATH:" in
        *":/home/linuxbrew/.linuxbrew/bin:"*) ;;
        *) PATH="$PATH:/home/linuxbrew/.linuxbrew/bin:/home/linuxbrew/.linuxbrew/sbin" ;;
    esac
    export HOMEBREW_PREFIX="${HOMEBREW_PREFIX:-/home/linuxbrew/.linuxbrew}"
fi

export PATH
