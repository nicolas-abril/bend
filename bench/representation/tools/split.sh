#!/bin/bash
# split.sh: rbtree and rbtree-ck on main, with the words shared but the node
# padded back to its old size (pad: tools in ../pad), and as built; 16
# placements, 1 round
W=/private/tmp/bend-opt/rep-work
cd $W
args=(); for p in rbtree rbtree-ck; do for v in base pad new; do args+=("${p}_$v=em/c_${p}_$v.c"); done; done
TM=$W/tools/tm ~/Software/supgen-bend/limit 7200 6144 python3 tools/swp.py --rts --rounds 1 --out sw/split.jsonl --wdir $W/sw/ws "${args[@]}" > sw/split.log 2>&1
python3 tools/swp.py --table sw/split.jsonl > sw/split.md
