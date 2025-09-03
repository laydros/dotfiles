#!/bin/bash

# Create fonts dir if it doesn't exist
mkdir -p ~/.local/share/fonts

# Download latest Hack Nerd Font release (complete)
cd ~/.local/share/fonts || exit
wget -q https://github.com/ryanoasis/nerd-fonts/releases/latest/download/Hack.zip
unzip Hack.zip -d Hack
rm Hack.zip

# Update font cache
fc-cache -fv

