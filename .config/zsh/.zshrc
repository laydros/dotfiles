# -*- conf-unix -*-

# source global alias file
[ -f "$XDG_CONFIG_HOME/shell/alias" ] && source "$XDG_CONFIG_HOME/shell/alias"
[ -f "$XDG_CONFIG_HOME/shell/func" ] && source "$XDG_CONFIG_HOME/shell/func"

# =========
#   INIT
# =========

# Lots borrowed from https://leahneukirchen.org/dotfiles/.zshrc

# Lowercased OS name used by the platform guards below: darwin, linux, freebsd...
export OS="$(uname | tr '[:upper:]' '[:lower:]')"

# Guard helper. Returns true when $1 is an available command and, when $2 is
# given, when we are also running on that OS.
#   __is_available eza              && alias ls='eza'
#   __is_available dircolors linux  && eval "$(dircolors -b)"
__is_available() {
  local prog="$1" os="$2"
  [[ -n "$os" && "$os" != "$OS" ]] && return 1
  command -v "$prog" >/dev/null 2>&1
}

# hopefully avoid PATH duplication
typeset -U PATH
# fpath picks up duplicates from brew shellenv running in nested shells;
# duplicate entries make compinit scan the same directory repeatedly.
typeset -U fpath FPATH

# Homebrew. Must run before compinit: shellenv is what puts brew's
# site-functions on fpath, and brew is not on PATH until it does.
if [[ -x /opt/homebrew/bin/brew ]]; then
   eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -x /usr/local/bin/brew ]]; then
   eval "$(/usr/local/bin/brew shellenv)"
elif [[ -x /home/linuxbrew/.linuxbrew/bin/brew ]]; then
   eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
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

# Hosts that should use a local ssh-agent (otherwise rely on agent forwarding or system default).
ssh_agent_hosts=("ibanez" "indy" "vox")

if [[ " ${ssh_agent_hosts[@]} " =~ " $(hostname) " ]]; then
    # Check if we can connect to an existing agent
    if [[ -z "$SSH_AUTH_SOCK" ]] || ! ssh-add -l >/dev/null 2>&1; then
        # Prefer the systemd-managed ssh-agent.service socket
        if [[ -S "$XDG_RUNTIME_DIR/openssh_agent" ]]; then
            export SSH_AUTH_SOCK="$XDG_RUNTIME_DIR/openssh_agent"
        else
            # Fall back to a session-scoped agent
            eval "$(ssh-agent -t 24h)" > /dev/null
        fi
    fi

    # Don't auto-add keys - let SSH do it on first use (AddKeysToAgent yes in ssh_config)
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
# homebrew shellenv now runs in the INIT section above, ahead of compinit

# automatically start tmux when sshing in
# in .zshrc, only for SSH sessions
if [[ -n "$SSH_CONNECTION" ]] && command -v tmux &>/dev/null && [[ -z "$TMUX" ]]; then
  tmux attach -t ssh 2>/dev/null || tmux new -s ssh
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

# Go
PATH=$HOME/.local/share/go/bin:$PATH

# sbin for homebrew
PATH="/usr/local/sbin:$PATH"

# for m3-info
if [[ "$OS" == "linux" && -d /home/m3db/data/linux/bin ]]; then
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
if [[ "$OS" == "darwin" ]]; then
  export DOCKER_HOST=unix://$HOME/.colima/docker.sock
fi

# Print a greeting message when shell is started.
# lsb_release is absent on Arch, Alpine and minimal Debian; os-release is the
# portable fallback there.
if __is_available lsb_release; then
   echo $USER@$HOST $(uname -srm) $(lsb_release -rcs)
elif [[ -r /etc/os-release ]]; then
   echo $USER@$HOST $(uname -srm) "$(. /etc/os-release && echo $VERSION_ID $VERSION_CODENAME)"
else
   echo $USER@$HOST $(uname -srm)
fi

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
if [[ "$OS" == "darwin" ]]; then
  # macOS's $HOST changes with dhcp, etc. Use ComputerName if possible.
  SHORT_HOST=$(scutil --get ComputerName 2>/dev/null) || SHORT_HOST=${HOST/.*/}
else
  SHORT_HOST=${HOST/.*/}
fi

# ===========
#   ALIASES
# ===========

# enable color support of ls and also add handy aliases.
# BSD ls (macOS, *BSD) takes CLICOLOR/LSCOLORS; GNU ls (Linux) takes --color.
case "$OS" in
    darwin|*bsd)  # macOS and FreeBSD/OpenBSD/NetBSD
        export CLICOLOR=1
        export LSCOLORS=GxFxCxDxBxegedabagaced
        alias ls='ls -GF'
        ;;
    linux)
        if __is_available dircolors; then
            test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
        fi
        alias ls='ls --color=auto -F'
        ;;
esac

# Colored completion listings. Must come after the dircolors call above, which
# is what populates LS_COLORS; macOS has no LS_COLORS equivalent, so this is a
# no-op there.
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"

# Use eza if available (overrides ls aliases from shell/alias)
if __is_available eza; then
    alias ls='eza'
    alias ll='eza -la --icons=auto'
    alias l='eza --icons=auto'
    alias la='eza -a --icons=auto'
    alias lsa='eza -a --icons=auto'
fi

# == nvm
# NVM_DIR is set to its XDG location in .zshenv, so it is deliberately not set
# here. Homebrew's nvm lives under $HOMEBREW_PREFIX/opt/nvm, which differs
# between Apple Silicon (/opt/homebrew), Intel macOS and Linuxbrew.
if [[ -n "$HOMEBREW_PREFIX" ]]; then
   [ -s "$HOMEBREW_PREFIX/opt/nvm/nvm.sh" ] && . "$HOMEBREW_PREFIX/opt/nvm/nvm.sh"
   [ -s "$HOMEBREW_PREFIX/opt/nvm/etc/bash_completion.d/nvm" ] && . "$HOMEBREW_PREFIX/opt/nvm/etc/bash_completion.d/nvm"
fi

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
__is_available zoxide && eval "$(zoxide init zsh)"

# fzf - fuzzy finder
# Ctrl+R: Fuzzy command history search
# Ctrl+T: Fuzzy file search (insert path into command)
# Alt+C:  Fuzzy cd into directory
# Configure fzf to use fd for file search (faster, respects .gitignore)
export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
# `fzf --zsh` emits both keybindings and completions, so this works whether fzf
# came from brew, apt, pacman or a git checkout. Requires fzf >= 0.48.
if __is_available fzf; then
   fzf_init="$(fzf --zsh 2>/dev/null)"
   if [[ -n "$fzf_init" ]]; then
      eval "$fzf_init"
   else
      print -u2 "fzf: 'fzf --zsh' returned nothing (needs fzf >= 0.48); keybindings not loaded"
   fi
   unset fzf_init
fi

# ===============
#   KEYBINDINGS
# ===============

# Terminals disagree on what Home/End/Delete/Shift-Tab send. Query terminfo
# rather than hardcoding escape sequences, so these behave the same in Ghostty,
# a Linux VT, tmux and over SSH. Emacs mode is set by `bindkey -e` above, so a
# bare bindkey lands in the right keymap.
zmodload zsh/terminfo 2>/dev/null

# Application keypad mode while the line editor is active. Without this the
# terminfo values below do not match what the terminal actually sends.
if (( ${+terminfo[smkx]} )) && (( ${+terminfo[rmkx]} )); then
   function zle-line-init() {
      echoti smkx
   }
   function zle-line-finish() {
      echoti rmkx
   }
   zle -N zle-line-init
   zle -N zle-line-finish
fi

# [Home] / [End]
[[ -n "${terminfo[khome]}" ]] && bindkey "${terminfo[khome]}" beginning-of-line
[[ -n "${terminfo[kend]}"  ]] && bindkey "${terminfo[kend]}"  end-of-line

# [Delete] - fall back to the common xterm sequence when terminfo is silent
if [[ -n "${terminfo[kdch1]}" ]]; then
   bindkey "${terminfo[kdch1]}" delete-char
else
   bindkey "^[[3~" delete-char
fi

# [Shift-Tab] - step backwards through the completion menu
[[ -n "${terminfo[kcbt]}" ]] && bindkey "${terminfo[kcbt]}" reverse-menu-complete

# [Ctrl-Left] / [Ctrl-Right] - move by word
bindkey '^[[1;5D' backward-word
bindkey '^[[1;5C' forward-word

# Edit the current command line in $EDITOR
autoload -Uz edit-command-line
zle -N edit-command-line
bindkey '^X^E' edit-command-line

# platform specific stuff
# (rust/cargo init is handled in .zshenv on every platform)
if [[ "$OS" == "darwin" ]]; then
   export STORE_LASTDIR=1
fi

# Lazy load rbenv - add shims to PATH immediately, defer full init until first use
if [[ -d "$HOME/.rbenv/shims" ]]; then
  export PATH="$HOME/.rbenv/shims:$PATH"
  rbenv() {
    unfunction rbenv
    eval "$(command rbenv init - zsh)"
    rbenv "$@"
  }
fi

# uv drops its shell env file here; absent on machines without uv
[ -f "$HOME/.local/bin/env" ] && . "$HOME/.local/bin/env"
