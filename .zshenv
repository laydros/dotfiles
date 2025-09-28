## -*- mode: conf-unix-*-
## -*- coding: utf-8 -*-
## vim: ts=2:sw=2:et:ft=zsh
#
# zshenv for $XDG_CONFIG_HOME
# for zsh-specific settings for non-interactive and interactive sessions

# setopt braceexpand


export LFS=/mnt/lfs

#export XDG_CONFIG_HOME=${$XDG_CONFIG_HOME:=${HOME}/.config}
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_CACHE_HOME=$HOME/.cache
export XDG_DATA_HOME=$HOME/.local/share
export XDG_STATE_HOME=$HOME/.local/state
export XDG_RUNTIME_DIR=/run/user/$UID

export ZDOTDIR="$XDG_CONFIG_HOME/zsh"

# for flatpak
#export XDG_DATA_DIRS=${XDG_DATA_DIRS}:var/lib/flatpak/exports/share:${XDG_DATA_HOME}/flatpak/exports/share
# set some programs to use XDG

#  less
export LESSHISTFILE="${XDG_CONFIG_HOME}/less/history"
export LESSKEY="${XDG_CONFIG_HOME}/less/keys"

# R    Display colours escape chars as-is (so they're displayed).
# i    Ignore case unless pattern has upper case chars.
# M    Display line numbers and position.
# Q    Never ring terminal bell.
# X    Don't clear the screen on exit.
# L    Ignore LESSOPEN – some Linux distros set this to broken defaults (*cough* Fedora *cough*).
export LESS="RiMQXL"

# stuff to keep $HOME clean
export XINITRC="$XDG_CONFIG_HOME/x11/xinitrc"
export XPROFILE="$XDG_CONFIG_HOME/x11/xprofile"
export XRESOURCES="$XDG_CONFIG_HOME/x11/xresources"
export GNUPGHOME="$XDG_CONFIG_HOME"/gnupg
export MPLAYER_HOME=$XDG_CONFIG_HOME/mplayer
export ELINKS_CONFDIR="$XDG_CONFIG_HOME"/elinks
export GOPATH="$XDG_DATA_HOME"/go
export GOBIN="$GOPATH/bin"
export GOMODCACHE="$XDG_CACHE_HOME/go/mod"
export RXVT_SOCKET="$XDG_RUNTIME_DIR"/urxvtd
export PYLINTHOME="$XDG_CONFIG_HOME"/pylint
export IPYTHONDIR="$XDG_CONFIG_HOME"/ipython
export PYTHON_HISTORY="$XDG_DATA_HOME"/python/history
export JUPYTER_CONFIG_DIR="$XDG_CONFIG_HOME"/jupyter
export DVDCSS_CACHE="$XDG_DATA_HOME"/dvdcss
export NOTMUCH_CONFIG="$XDG_CONFIG_HOME"/notmuch/notmuchrc
export NMBGIT="$XDG_DATA_HOME"/notmuch/nmbug
export PASSWORD_STORE_DIR="$XDG_DATA_HOME"/pass
export WEECHAT_HOME="$XDG_CONFIG_HOME"/weechat
export DOCKER_CONFIG="$XDG_CONFIG_HOME"/docker
export CARGO_HOME="$XDG_DATA_HOME"/cargo
export RUSTUP_HOME="$XDG_DATA_HOME"/rustup

export ANSIBLE_HOME="$XDG_DATA_HOME"/ansible
export HISTFILE="${XDG_STATE_HOME}"/bash/history

export BUNDLE_USER_CONFIG="$XDG_CONFIG_HOME"/bundle
export BUNDLE_USER_CACHE="$XDG_CACHE_HOME"/bundle
export BUNDLE_USER_PLUGIN="$XDG_DATA_HOME"/bundle
export GEM_HOME="$XDG_DATA_HOME"/gem
export PLATFORMIO_CORE_DIR="$XDG_DATA_HOME"/platformio
export NVM_DIR="$XDG_DATA_HOME"/nvm
export SQLITE_HISTORY=$XDG_DATA_HOME/sqlite_history
export GNUPGHOME="$XDG_DATA_HOME"/gnupg
export TLDR_CACHE_DIR="$XDG_CACHE_HOME"/tldr
export TERMINFO="$XDG_DATA_HOME"/terminfo                                     
export TERMINFO_DIRS="$XDG_DATA_HOME"/terminfo:/usr/share/terminfo
export COLIMA_HOME="$XDG_DATA_HOME/colima"
export OLLAMA_HOME="$XDG_DATA_HOME/ollama"
export W3M_DIR="$XDG_DATA_HOME"/w3m
# Vim XDG compliance
#export VIMINIT='let $MYVIMRC="$XDG_CONFIG_HOME/vim/vimrc" | source $MYVIMRC'

# since I don't have any options set, this breaks
# export WGETRC="$XDG_CONFIG_HOME/wgetrc"

# Unix means English and 24h clock.  But do use UTF8!  And sort like a machine.
export LANG=en_US.UTF-8
export LC_CTYPE=$LANG
export LC_COLLATE=C
export LC_TIME=C

# less: use UTF-8
export LESSCHARSET=UTF-8

# add cargo for rust
. "$HOME/.local/share/cargo/env"

# == SITE LOCAL CONFIG

# [[ -e ~/.zshenv.local ]] && . ~/.zshenv.local || :

