# $OpenBSD: dot.profile,v 1.7 2020/01/24 02:09:51 okan Exp $
#
# sh/ksh initialization

HISTFILE=~/.ksh_history

export VISUAL=vi
export EDITOR=vi

export LC_CTYPE="en_US.UTF-8"

export PS1='\u@\h:\w \$ '

PATH=$HOME/bin:/bin:/sbin:/usr/bin:/usr/sbin:/usr/X11R6/bin:/usr/local/bin:/usr/local/sbin:/usr/games
export PATH HOME TERM
