#!/bin/sh

img=/tmp/swaylock.png

#scrot -o $img
grimshot save screen $img
convert $img -scale 10% -scale 1000% $img

swaylock -i $img
