## -*- mode: conf-unix-*-
## -*- coding: utf-8 -*-
## vim: ts=2:sw=2:et:ft=zsh
#
# Stub: hand off to $ZDOTDIR/.zshenv.
# Real content lives at $XDG_CONFIG_HOME/zsh/.zshenv to keep $HOME clean.
# The fallback default below only matters for the first zsh of a session
# (no inherited ZDOTDIR); child shells get ZDOTDIR from the parent env.

export ZDOTDIR="${ZDOTDIR:-$HOME/.config/zsh}"
[[ -r "$ZDOTDIR/.zshenv" ]] && source "$ZDOTDIR/.zshenv"
