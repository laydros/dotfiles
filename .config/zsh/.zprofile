# zprofile (XDG location) — sourced by login shells, after /etc/zprofile.
# macOS /etc/zprofile runs path_helper, which demotes our PATH entries below
# /usr/bin; re-sourcing path.zsh puts them back in front.

source "$ZDOTDIR/path.zsh"
