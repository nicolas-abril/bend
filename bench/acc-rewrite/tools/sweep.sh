#!/bin/bash
# sweep.sh W OUT.jsonl [ROUNDS] [VARIANTS..]: 16-position placement sweep of
# the queens variants in W/q (setup.sh), every heavy run under supgen-bend's
# limit (one at a time, 6 GB). Table: swp.py --table OUT.jsonl
W=${1:-/private/tmp/bend-opt/acc2-work}
OUT=$2; R=${3:-2}; shift 3
H=$(cd "$(dirname "$0")" && pwd)
vs=("$@"); [ ${#vs[@]} -eq 0 ] && vs=(queens s1 s2a s2b s12a s12b r1)
args=()
for f in "${vs[@]}"; do for b in main int; do args+=("${f}_$b=$W/q/${f}_$b.c"); done; done
uptime
TM=$W/tools/tm exec ~/Software/supgen-bend/limit 10800 6144 \
  python3 $H/swp.py --rts --rounds $R --out $OUT --wdir $W/swp-$(basename $OUT .jsonl) "${args[@]}"
