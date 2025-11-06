# -*- conf-unix -*-

# source global alias file
[ -f "$XDG_CONFIG_HOME/shell/alias" ] && source "$XDG_CONFIG_HOME/shell/alias"
[ -f "$XDG_CONFIG_HOME/shell/func" ] && source "$XDG_CONFIG_HOME/shell/func"

# =========
#   INIT
# =========

# Lots borrowed from https://leahneukirchen.org/dotfiles/.zshrc

# hopefully avoid PATH duplication
typeset -U PATH

## completion for homebrew: https://docs.brew.sh/Shell-Completion
if type brew &>/dev/null; then
	FPATH=$(brew --prefix)/share/zsh/site-functions:$FPATH
fi

unsetopt autocd
bindkey -e
# End of lines configured by zsh-newuser-install
# The following lines were added by compinstall
zstyle :compinstall filename '/home/laydros/.config/zsh/.zshrc'

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

export EDITOR="nvim"
export VISUAL="nvim"

# Start with system PATH, then add our directories in priority order
PATH=$HOME/bin:$HOME/.local/bin:$PATH

# Rust
PATH=$HOME/.local/share/cargo/bin:$PATH

# sbin for homebrew
PATH="/usr/local/sbin:$PATH"

# for m3-info
if [[ "$OSTYPE" != "darwin" && "$OSTYPE" != "cygwin" && "$OSTYPE" != "msys" && "$OSTYPE" != "win32" ]]; then
    PATH=/home/m3db/data/linux/bin:$PATH
fi

export PATH

# Load completions with daily cache
autoload -Uz compinit
typeset -i updated_at=$(date +'%j' -r "$XDG_CACHE_HOME/zsh/zcompdump-$ZSH_VERSION" 2>/dev/null || stat -f '%Sm' -t '%j' "$XDG_CACHE_HOME/zsh/zcompdump-$ZSH_VERSION" 2>/dev/null || echo 0)
typeset -i today=$(date +'%j')
if [ $updated_at -ne $today ]; then
  compinit -d "$XDG_CACHE_HOME/zsh/zcompdump-$ZSH_VERSION"
else
  compinit -C -d "$XDG_CACHE_HOME/zsh/zcompdump-$ZSH_VERSION"
fi

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

# Python virtual environment indicator
# Disable venv's automatic prompt modification - we'll handle it ourselves
export VIRTUAL_ENV_DISABLE_PROMPT=1

function venv_info {
    [[ -n "$VIRTUAL_ENV" ]] && echo " %F{green}(v)%f"
}

# Show hostname only on SSH or remote connections
if [[ -n "$SSH_CONNECTION" ]]; then
    PROMPT='%B%F{green}%m%f%F{red}%(?.. %??)%(1j. %j&.)%f%b %F{cyan}%2~%f$(venv_info)${vcs_info_msg_0_} %B%#%b '
else
    PROMPT='%F{red}%(?.. %??)%(1j. %j&.)%f%F{cyan}%2~%f$(venv_info)${vcs_info_msg_0_} %B%#%b '
fi

# enable substitution for prompt
setopt prompt_subst

# Load version control info
autoload -Uz vcs_info
precmd() { vcs_info }

# Format the vcs_info_msg_0_ variable
# Shows: (main) clean, (main*) unstaged changes, (main+) staged, (main*+) both
# If this causes slowness in large repos or network mounts, disable with:
#   zstyle ':vcs_info:*' check-for-changes false
zstyle ':vcs_info:*' check-for-changes true
zstyle ':vcs_info:*' unstagedstr '*'
zstyle ':vcs_info:*' stagedstr '+'
zstyle ':vcs_info:git:*' formats ' %F{yellow}(%b%u%c)%f'

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

# Use eza if available (overrides ls aliases from shell/alias)
if command -v eza >/dev/null 2>&1; then
    alias ls='eza'
    alias ll='eza -la --icons=auto'
    alias l='eza --icons=auto'
    alias la='eza -a --icons=auto'
    alias lsa='eza -a --icons=auto'
fi

# == nvm on the mac
export NVM_DIR="$HOME/.nvm"
[ -s "/usr/local/opt/nvm/nvm.sh" ] && . "/usr/local/opt/nvm/nvm.sh"  # This loads nvm
[ -s "/usr/local/opt/nvm/etc/bash_completion.d/nvm" ] && . "/usr/local/opt/nvm/etc/bash_completion.d/nvm"  # This loads nvm bash_completion

cx() {
    # If no argument was given, show a helpful message
    if [ -z "$1" ]; then
        echo "cdl: missing directory argument"
        return 1
    fi

    # Expand the argument (handles ~, relative paths, etc.)
    target="${1/#\~/$HOME}"

    # Try to change into the directory; abort if it fails
    if ! cd "$target" 2>/dev/null; then
        echo "cdl: cannot cd to '$target'"
        return 1
    fi

    # List the directory contents
    eza -la
}

# source zsh functions
fpath+=${ZDOTDIR:-~}/.zsh_functions
eval "$(zoxide init zsh)"

# fzf - fuzzy finder
# Ctrl+R: Fuzzy command history search
# Ctrl+T: Fuzzy file search (insert path into command)
# Alt+C:  Fuzzy cd into directory
# Configure fzf to use fd for file search (faster, respects .gitignore)
export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
source $(brew --prefix)/opt/fzf/shell/key-bindings.zsh
source $(brew --prefix)/opt/fzf/shell/completion.zsh

# platform specific stuff
if [[ $OSTYPE = darwin* ]]; then
   export STORE_LASTDIR=1

elif [[ $OSTYPE = linux* ]]; then
    # rust init now handled in .zshenv
fi

# Lazy load rbenv - add shims to PATH immediately, defer full init until first use
export PATH="$HOME/.rbenv/shims:$PATH"
rbenv() {
  unfunction rbenv
  eval "$(command rbenv init - zsh)"
  rbenv "$@"
}

