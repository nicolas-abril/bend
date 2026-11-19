#!/usr/bin/env bash
# cnt_build.sh IN.c OUT  -> OUT.c (patched), OUT.cnt (-DPAR_COUNT), OUT.plain
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
python3 "$here/patch_counters.py" "$1" "$2.c"
cc -std=c11 -O3 -w -DPAR_COUNT "$2.c" -o "$2.cnt" -lpthread
cc -std=c11 -O3 -w "$2.c" -o "$2.plain" -lpthread
