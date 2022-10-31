#!/bin/sh

directory=$HOME/stdoc/
today=$(date -u +"%Y-%m-%d")
filename=${directory}tasks-${today}.md

echo "creating $filename"
touch "$filename"

printf "%s: \n\n" "$today" > "$filename"
echo "-  **TODO**" >> "$filename"

