# PATH.

# Guarded so re-sourcing does not stack duplicate entries.
case ":$PATH:" in
    *":$HOME/.local/bin:"*) ;;
    *) PATH="$HOME/.local/bin:$HOME/bin:$PATH" ;;
esac
export PATH

# Homebrew: /opt/homebrew on Apple Silicon, /usr/local on Intel.
#
# This DOES use `brew shellenv`, so brew is prepended -- the opposite of the
# Linux side, where Bazzite appends it so system binaries win. Here brew is the
# primary source of CLI tooling. That divergence is why this file is per-OS.
for _brew in /opt/homebrew/bin/brew /usr/local/bin/brew; do
    if [ -x "$_brew" ]; then
        eval "$("$_brew" shellenv)"
        break
    fi
done
unset _brew
