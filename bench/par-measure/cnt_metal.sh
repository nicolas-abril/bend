#!/usr/bin/env bash
# cnt_metal.sh IN.c OUT -> OUT.c (patched) and OUT, a counted Metal build
# (the perf gate's PAR-GPU cc line plus -DPAR_COUNT), with OUT.gpu written.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
python3 "$here/patch_counters.py" "$1" "$2.c"
cc -std=c11 -O3 -w -DPAR_COUNT -DBEND_METAL=1 -x objective-c -fobjc-arc "$2.c" \
  -o "$2" -lpthread -framework Metal -framework Foundation
"$(cd "$(dirname "$2")" && pwd)/$(basename "$2")" +RTS --gpu-build -RTS
