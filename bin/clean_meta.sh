#! /bin/sh

set -e

file="$1"

sed -i \
-e 's/author: your name/author: jason/' \
-e 's/company: your company (optional)/company:/' \
-e 's/license: license (GPL-2.0-or-later, MIT, etc)/license: GPL-2.0-or-later/' \
$file

# sed -i 's/author: your name/author: jason/'
# sed -i 's/company: your company (optional)/company:/'
# sed -i 's/license: license (GPL-2.0-or-later, MIT, etc)/license: GPL-2.0-or-later/'
