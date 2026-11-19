#!/usr/bin/env bash
# build.sh ROOT SRC OUT [CFLAGS...]
#
# Emits SRC's C with the compiler in the bend checkout ROOT (OUT.c) and builds
# it the way the perf gate builds its CPU cells (OUT): cc -std=c11 -O3. Extra
# arguments go to cc (e.g. -DPAR_COUNT for a counted build of a patched C).
# With BEND_GPU=1 it builds the binary the way a user gets it instead,
# `bend SRC -o OUT`, which also writes OUT.gpu (the Metal program).
set -euo pipefail
root=$1; src=$2; out=$3; shift 3
mkdir -p "$(dirname "$out")"
if [ "${BEND_GPU:-0}" = 1 ]; then
  bun "$root/bend2/main.ts" "$src" -o "$out" > "$out.build.txt" 2>&1
  exit 0
fi
if [ "${SKIP_EMIT:-0}" != 1 ]; then
  bun "$root/bend2/main.ts" "$src" -o "$out.c" > "$out.build.txt" 2>&1
fi
cc -std=c11 -O3 -w "$@" "$out.c" -o "$out" -lpthread >> "$out.build.txt" 2>&1
