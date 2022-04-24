# $OpenBSD: dot.profile,v 1.7 2020/01/24 02:09:51 okan Exp $
#
# sh/ksh initialization

HISTFILE=~/.ksh_history

VISUAL=vi
EDITOR=vi
LC_CTYPE="en_US.UTF-8"
PS1='\u@\h:\w \$ '

PATH=$HOME/bin:$HOME/.local/bin:/bin:/sbin:/usr/bin:/usr/sbin:/usr/X11R6/bin:/usr/local/bin:/usr/local/sbin:/usr/games
export PATH HOME TERM PS1

set -o emacs

function sptouc
{
    for f in *\ *; do mv "$f" "${f// /_}"; done
}

