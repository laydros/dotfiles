# PATH and Homebrew for every zsh, interactive or not.
#
# Sourced from .zshenv so non-interactive shells (ssh host 'cmd', scripts with
# a zsh shebang) get it, and again from .zprofile because macOS /etc/zprofile
# runs path_helper in between and demotes these dirs below /usr/bin. Sourcing
# twice is safe: with typeset -U, re-prepending dedupes and restores position.
#
# Must stay silent. .zshenv runs for scp and rsync too, and any output breaks
# them. Every step is guarded so a fresh box without brew or these dirs is fine.

# hopefully avoid PATH duplication
typeset -U PATH path
# fpath picks up duplicates from brew shellenv running in nested shells;
# duplicate entries make compinit scan the same directory repeatedly.
typeset -U fpath FPATH

# Homebrew. Must run before compinit in .zshrc: shellenv is what puts brew's
# site-functions on fpath, and brew is not on PATH until it does.
if [[ -x /opt/homebrew/bin/brew ]]; then
   eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -x /usr/local/bin/brew ]]; then
   eval "$(/usr/local/bin/brew shellenv)"
elif [[ -x /home/linuxbrew/.linuxbrew/bin/brew ]]; then
   eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
fi

# Start with system PATH, then add our directories in priority order
PATH=$HOME/bin:$HOME/.local/bin:$PATH

# Rust
PATH=$HOME/.local/share/cargo/bin:$PATH

# Go
PATH=$HOME/.local/share/go/bin:$PATH

# sbin for homebrew
PATH="/usr/local/sbin:$PATH"

# for m3-info. $OSTYPE, not $OS: $OS is set in .zshrc, which has not run yet.
if [[ "$OSTYPE" == linux* && -d /home/m3db/data/linux/bin ]]; then
    PATH=/home/m3db/data/linux/bin:$PATH
fi

export PATH
