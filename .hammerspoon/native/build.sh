#!/bin/sh
set -eu
native_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
/usr/bin/clang -Wall -Wextra -Werror -O2 -framework ApplicationServices \
  "$native_dir/space-key.c" -o "$native_dir/space-key"
