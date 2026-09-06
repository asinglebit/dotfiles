# PATH.

# ~/.local/bin carries claude and other user-installed binaries; ~/bin is the
# traditional spot. Guarded so re-sourcing does not stack duplicate entries.
case ":$PATH:" in
    *":$HOME/.local/bin:"*) ;;
    *) PATH="$HOME/.local/bin:$HOME/bin:$PATH" ;;
esac
export PATH

# Homebrew. Apple Silicon installs under /opt/homebrew, Intel under /usr/local.
#
# Note this DOES use `brew shellenv`, i.e. brew is prepended -- the opposite of
# the Linux side, where Bazzite deliberately appends it so system binaries win.
# On macOS brew is the primary source of CLI tooling and there is no curated
# system set to protect, so the upstream default is the right one here. The
# divergence is why this file is per-OS rather than shared.
for _brew in /opt/homebrew/bin/brew /usr/local/bin/brew; do
    if [ -x "$_brew" ]; then
        eval "$("$_brew" shellenv)"
        break
    fi
done
unset _brew
