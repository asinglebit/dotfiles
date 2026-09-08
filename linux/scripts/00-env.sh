# PATH.

# Guarded so re-sourcing does not stack duplicate entries.
case ":$PATH:" in
    *":$HOME/.local/bin:"*) ;;
    *) PATH="$HOME/.local/bin:$HOME/bin:$PATH" ;;
esac

# Homebrew, APPENDED -- never `brew shellenv`, which prepends and would let
# brew's binaries beat the system's, against Bazzite's policy. Repeated from
# /etc/profile.d/brew.sh because that file only runs for interactive shells,
# and mise is itself a brew install.
if [ -d /home/linuxbrew/.linuxbrew/bin ]; then
    case ":$PATH:" in
        *":/home/linuxbrew/.linuxbrew/bin:"*) ;;
        *) PATH="$PATH:/home/linuxbrew/.linuxbrew/bin:/home/linuxbrew/.linuxbrew/sbin" ;;
    esac
    export HOMEBREW_PREFIX="${HOMEBREW_PREFIX:-/home/linuxbrew/.linuxbrew}"
fi

export PATH
