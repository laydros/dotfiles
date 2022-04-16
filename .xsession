#!/bin/sh
# ~/.xinitrc - may want to symlink to .xinitrc

LANG= xclock -strftime "%a %e %b %Y %H:%M" &
export LANG=en_US.UTF-8

xrdb -merge $HOME/.Xresources

xidle &

eval $(ssh-agent)

xset -b
setxkbmap -option 'ctrl:nocaps'
xsetroot -solid black
xterm -e '. .profile;tmux a || tmux' &
exec cwm
