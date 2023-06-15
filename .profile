# ~/.profile: executed by the command interpreter for login shells.
# This file is not read by bash(1), if ~/.bash_profile or ~/.bash_login
# exists.
# see /usr/share/doc/bash/examples/startup-files for examples.
# the files are located in the bash-doc package.

# the default umask is set in /etc/profile; for setting the umask
# for ssh logins, install and configure the libpam-umask package.
#umask 022

HISTFILE=~/.ksh_history

VISUAL=vi
EDITOR=vi
LC_CTYPE="en_US.UTF-8"
PS1='\u@\h:\w \$ '

PATH=$HOME/bin:/usr/bin:/sbin:/bin:/usr/sbin:/usr/X11R6/bin:/usr/local/bin:/usr/local/sbin:/usr/games:$PATH
export PATH HOME TERM PS1

set -o emacs

function sptouc
{
    for f in *\ *; do mv "$f" "${f// /_}"; done
}

#. "$HOME/.cargo/env"

# if running bash
if [ -n "$BASH_VERSION" ]; then
    # include .bashrc if it exists
    if [ -f "$HOME/.bashrc" ]; then
	. "$HOME/.bashrc"
    fi
fi

# set PATH so it includes user's private bin if it exists
if [ -d "$HOME/bin" ] ; then
    PATH="$HOME/bin:$PATH"
fi

# set PATH so it includes user's private bin if it exists
if [ -d "$HOME/.local/bin" ] ; then
    PATH="$HOME/.local/bin:$PATH"
fi
#eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
