# -*- conf-unix -*-

# =========
#   INIT
# =========

# Lots borrowed from https://leahneukirchen.org/dotfiles/.zshrc


#PATH=/opt/homebrew/sbin:/opt/homebrew/bin:/opt/homebrew/opt/python@3.9/libexec/bin:$PATH

## completion for homebrew: https://docs.brew.sh/Shell-Completion
if type brew &>/dev/null; then
	FPATH=$(brew --prefix)/share/zsh/site-functions:$FPATH
fi

unsetopt autocd
bindkey -e
# End of lines configured by zsh-newuser-install
# The following lines were added by compinstall
zstyle :compinstall filename '/home/laydros/.config/zsh/.zshrc'

autoload -Uz compinit
compinit
# End of lines added by compinstall

# == HISTORY

HISTFILE="$XDG_CONFIG_HOME/zsh/histfile"
HISTSIZE=1100000            # Max entries to keep in memory
SAVEHIST=1000000            # Max entries to save to file

HISTORY_IGNORE="(ls|cd|pwd|exit|cd)*"
#HIST_STAMPS="yyyy-mm-dd" 
HISTTIME_FORMAT="yyyy-mm-dd"

setopt EXTENDED_HISTORY     # add timestamps to history in ':start:elapsed;command' format
setopt APPEND_HISTORY       # Append to history, rather than overwriting
setopt SHARE_HISTORY        # Share history between sessions
setopt INC_APPEND_HISTORY   # append immediately rather than only at exit
setopt HIST_IGNORE_DUPS     # Don't add to history if it's the same as previous event
setopt HIST_IGNORE_ALL_DUPS # Remove older event if new event is duplicate.
setopt HIST_SAVE_NO_DUPS    # older commands that duplicate newer ones are omitted.
setopt HIST_IGNORE_SPACE    # do not record events starting with space
setopt HIST_REDUCE_BLANKS   # remove superflous blanks from commands being added to history
setopt HIST_VERIFY          # ask for confirmation every time you bang (!) a command


# == THEMING

## These are already done by zsh-newuser-install with
## slightly different option flags
#autoload -U compinit colors zcalc
#compinit -d

autoload -U colors zcalc
colors

# possible fix for very slow autocomplete in git repo
# https://stackoverflow.com/questions/9810327/zsh-auto-completion-for-git-takes-significant-amount-of-time-can-i-turn-it-off/9810485#9810485

__git_files () { 
    _wanted files expl 'local files' _files     
}

# == SSH Agent

# Hosts that should use ssh-agent with 24-hour timeout
ssh_agent_hosts=("ibanez" "indy")

if [[ " ${ssh_agent_hosts[@]} " =~ " $(hostname) " ]]; then
    # Check if we can connect to existing agent
    if [[ -z "$SSH_AUTH_SOCK" ]] || ! ssh-add -l >/dev/null 2>&1; then
        # Try to use the system openssh agent first
        if [[ -S "/run/user/$(id -u)/openssh_agent" ]]; then
            export SSH_AUTH_SOCK="/run/user/$(id -u)/openssh_agent"
        else
            # Start our own agent
            eval "$(ssh-agent -t 24h)"
        fi
    fi
    
    # Don't auto-add keys - let SSH do it on first use
    # (Remove the auto-add section that was prompting immediately)
fi

# if [[ $OSTYPE != darwin* ]]; then
#    if ! pgrep -u "$USER" ssh-agent > /dev/null; then
#       ssh-agent -t 1h > "$XDG_RUNTIME_DIR/ssh-agent.env"
#    fi
#    if [[ ! -f "$SSH_AUTH_SOCK" ]]; then
#       source "$XDG_RUNTIME_DIR/ssh-agent.env" >/dev/null
#    fi
# fi
# 
# set homebrew stuff for mac and linux
if [[ "$OSTYPE" = darwin* ]]; then
   eval "$(/opt/homebrew/bin/brew shellenv)"
else
   eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
fi

# =============
#   EXPORT
# =============

PATH=$HOME/bin:$HOME/.local/bin:$PATH
# for rust
PATH=$HOME/.local/share/cargo/bin:$PATH
# for brew
PATH=/opt/homebrew/sbin:/opt/homebrew/bin:/opt/homebrew/opt/python@3.9/libexec/bin:$PATH
# for go
PATH=$HOME/.local/share/go/bin:$PATH
# for m3-info
if [[ "$OSTYPE" != "darwin" && "$OSTYPE" != "cygwin" && "$OSTYPE" != "msys" && "$OSTYPE" != "win32" ]]; then
    PATH=/home/m3db/data/linux/bin:$PATH
fi

export PATH

compinit -d "$XDG_CACHE_HOME"/zsh/zcompdump-"$ZSH_VERSION"

# Color man pages
export LESS_TERMCAP_mb=$'\E[01;32m'
export LESS_TERMCAP_md=$'\E[01;32m'
export LESS_TERMCAP_me=$'\E[0m'
export LESS_TERMCAP_se=$'\E[0m'
export LESS_TERMCAP_so=$'\E[01;47;34m'
export LESS_TERMCAP_ue=$'\E[0m'
export LESS_TERMCAP_us=$'\E[01;36m'
export LESS=-R

# == PROMPT

# %B (%b) - turn on and off bold
# %F{red} (%f) - turn on and off red
# the chunk of %(?.. %??)%(1j. %j&.) seems to show last cmd error code

#PS1='%B%m%F{red}%(?.. %??)%(1j. %j&.)%f%b %F{cyan}%2~ %f%B%#%b '
PROMPT='%B%m%F{red}%(?.. %??)%(1j. %j&.)%f%b %F{cyan}%2~ %f%B%#%b '

## Test some manjaro zsh stuff

# enable substitution for prompt
setopt prompt_subst
# Maia prompt
#PROMPT="%B%{$fg[cyan]%}%(4~|%-1~/.../%2~|%~)%u%b >%{$fg[cyan]%}>%B%(?.%{$fg[cyan]%}.%{$fg[red]%})>%{$reset_color%}%b "
#RPROMPT="%{$fg[red]%} %(?..[%?])"


# set docker to use colima on Mac only
if [[ "$(uname)" == "Darwin" ]]; then
  export DOCKER_HOST=unix://$HOME/.config/colima/docker.sock
fi

# Print a greeting message when shell is started
if [[ "$OSTYPE" = darwin* ]]; then
   echo $USER@$HOST  $(uname -srm)
else
   echo $USER@$HOST  $(uname -srm) $(lsb_release -rcs)
fi

zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"         # Colored completion (different colors for dirs/files/etc)
zstyle ':completion:*' rehash true                              # automatically find new executables in path
# Speed up completions
zstyle ':completion:*' accept-exact '*(N)'
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path $XDG_CONFIG_HOME/zsh/cache

# options to look into
setopt NO_BG_NICE # don't nice background tasks
setopt NO_HUP
# setopt NO_LIST_BEEP
# setopt LOCAL_OPTIONS # allow functions to have local options
# setopt LOCAL_TRAPS # allow functions to have local traps
setopt PROMPT_SUBST
# setopt CORRECT               # auto correct mistakes
# setopt COMPLETE_IN_WORD
# setopt IGNORE_EOF

setopt C_BASES
setopt OCTAL_ZEROES
setopt PRINT_EIGHT_BIT
setopt SH_NULLCMD
setopt AUTO_CONTINUE
setopt PATH_DIRS
setopt NO_NOMATCH
setopt EXTENDED_GLOB
disable -p '^'

setopt LIST_PACKED
setopt BASH_AUTO_LIST
setopt NO_AUTO_MENU
setopt NO_CORRECT
setopt NO_ALWAYS_LAST_PROMPT
setopt NO_FLOW_CONTROL

# Figure out the SHORT hostname
if [[ "$OSTYPE" = darwin* ]]; then
  # macOS's $HOST changes with dhcp, etc. Use ComputerName if possible.
  SHORT_HOST=$(scutil --get ComputerName 2>/dev/null) || SHORT_HOST=${HOST/.*/}
else
  SHORT_HOST=${HOST/.*/}
fi

# ===========
#   ALIASES
# ===========

# enable color support of ls and also add handy aliases
# Detect OS type (macOS, Linux, or BSD)
case "$(uname)" in
    Darwin)  # macOS
        export CLICOLOR=1
        export LSCOLORS=GxFxCxDxBxegedabagaced
        alias ls='ls -GF'
        ;;
    Linux)  # Linux
        if command -v dircolors >/dev/null 2>&1; then
            test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
        fi
        alias ls='ls --color=auto -F'
        ;;
    *BSD)  # BSD variants (including FreeBSD, OpenBSD, NetBSD)
        export CLICOLOR=1
        export LSCOLORS=GxFxCxDxBxegedabagaced
        alias ls='ls -GF'
        ;;
esac

# Some more ls aliases (compatible across systems)
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'

# Enable color for grep (works on Linux and BSD/macOS)
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'
    
# if using exa
#alias ls="exa --color=auto -a -g"

# for wireguard
alias vpnup='sudo wg-quick up f500'
alias vpndown='sudo wg-quick down f500'
alias dnsfix='sudo /usr/sbin/networksetup -setdnsservers Wi-Fi "Empty"'

#alias df='df -h -x"squashfs"'
alias sort='LC_ALL=C sort'
# alias em='emacsclient -n'
alias dotf='ls .[a-zA-Z0-9_]*'
alias qr='qrencode -t UTF8'
alias cp="cp -iv"                    # confirm before overwriting, verbose
alias cat="bat -p"
alias clear="clear -x"
alias ip="ip -c"
alias feh="echo imv"

# alias ls='LC_COLLATE=C ls -FG'

# == Aliases for XDG
alias wget="wget --hsts-file=$XDG_CACHE_HOME/wget-hsts"
alias mbsync="mbsync -c $XDG_CONFIG_HOME/isync/mbsyncrc"
alias irssi="irssi --config=$XDG_CONFIG_HOME/irssi/config --home=$XDG_DATA_HOME/irssi"
alias gpg2="gpg2 --homedir $XDG_DATA_HOME/gnupg"
alias dosbox="dosbox -conf $XDG_CONFIG_HOME/dosbox/dosbox.conf"
alias sqlite3="sqlite3 -init $XDG_CONFIG_HOME/sqlite3/sqliterc"
alias mocp="mocp -M $XDG_CONFIG_HOME/moc"

# Add an "alert" alias for long running commands.  Use like so:
#   sleep 10; alert
alias alert='notify-send --urgency=low -i "$([ $? = 0 ] && echo terminal || echo error)" "$(history|tail -n1|sed -e '\''s/^\s*[0-9]\+\s*//;s/[;&|]\s*alert$//'\'    ')"'

# == nvm on the mac

export NVM_DIR="$HOME/.nvm"
[ -s "/usr/local/opt/nvm/nvm.sh" ] && . "/usr/local/opt/nvm/nvm.sh"  # This loads nvm
[ -s "/usr/local/opt/nvm/etc/bash_completion.d/nvm" ] && . "/usr/local/opt/nvm/etc/bash_completion.d/nvm"  # This loads nvm bash_completion

# == calculator
c() { printf "%s\n" "$@" | bc -l }

# == To try from leahneukirchen.org

# keep - poor man's version control, make freshly numbered copies
keep() {
  local f v
  [[ $# = 0 ]] && return 255
  for f; do
    f=$f:A
    v=($f.<->(nOnN[1]))
    if [[ -n "$v" ]] && cmp $v $f >/dev/null 2>&1; then
      print -u2 $v not modified
    else
      cp -va $f $f.$((${${v:-.0}##*.} + 1))
    fi
  done
}

# 0x0 FILE - paste to 0x0.st
# 16dec2015  +chris+
0x0() { curl -F "file=@${1:--}" https://0x0.st/ }

# ixio FILE - paste to ix.io
# 02apr2018  +leah+
ixio() { curl -F "f:1=@${1:--}" http://ix.io/ }

# zpass - generate random password
# 01nov2014  +chris+
# 10mar2017  +leah+  default to length 12
zpass() {
  LC_ALL=C tr -dc '0-9A-Za-z_@#%*,.:?!~' </dev/urandom | head -c${1:-12}
  echo
}

# cde - cd to working directory of current emacs buffer
# 11nov2014  +chris+
# 13dec2017  +leah+  print when not on a tty
# 26nov2019  +leah+  append $1
cde() {
  local op=print
  [[ -t 1 ]] && op=cd
  $op ${(A):-${(Q)~$(emacsclient -e '(with-current-buffer
                                       (window-buffer (selected-window))
                                       default-directory) ')}${1:-/.}}
}

# ecat - print current emacs buffer
# 15aug2016  +chris+
ecat() {
  () {
    emacsclient -e '(with-current-buffer (window-buffer (selected-window))
                      (write-region (point-min) (point-max) "'$1'" nil :quiet))
                   ' >/dev/null &&
    cat $1
  } =(:)
}

test -e "${HOME}/.iterm2_shell_integration.zsh" && source "${HOME}/.iterm2_shell_integration.zsh"

# sbin for homebrew
export PATH="/usr/local/sbin:$PATH"
# source zsh functions
fpath+=${ZDOTDIR:-~}/.zsh_functions

# from walk github page  https://github.com/antonmedv/walk
function lk {
  cd "$(walk "$@")"
}

# platform specific stuff
if [[ $OSTYPE = darwin* ]]; then
   export STORE_LASTDIR=1

elif [[ $OSTYPE = linux* ]]; then
   . "/home/laydros/.local/share/cargo/env"
   . "/home/laydros/.config/broot/launcher/bash/br"
fi


