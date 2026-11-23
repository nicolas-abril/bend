#!/usr/bin/env bash
# go_sp.sh: redo the sp checks after a change to opt/par-split (244 programs, lane, memory check, new tests)
set -u
H=$(cd "$(dirname "$0")" && pwd); P=/private/tmp/bend-opt/par; W=$P/work; LN=$P/lane
log() { echo "$(date +%H:%M) $*" >> $W/go_sp.log; }
rm -rf $P/b244/c/sp $P/b244/bin/sp $P/b244/res/sp.jsonl $LN/c/sp $LN/c/sp.* $LN/build/sp $LN/c/spnew* $LN/build/spnew
python3 -I $H/emit244.py $P/split sp > $W/emit244_sp.txt 2>&1; log "244 sp emitted"
python3 -I $H/run244.py sp > $W/run244_sp.txt 2>&1; cp $P/b244/res/sp.jsonl $W/b244_sp.jsonl; log "244 sp run"
python3 -I $H/lane2.py emit $P/split sp $LN/tests.list > $LN/emit_sp.log 2>&1; log "lane sp emitted"
python3 -I $H/lane2.py run sp $LN/tests.list > $LN/run_sp.log 2>&1; log "lane sp run"
python3 -I $H/lane2.py run sp $LN/tests.list --mem --only $LN/forktests.txt > $LN/mem_sp.log 2>&1; log "mem sp run"
python3 -I $H/lane2.py emit $P/split spnew $LN/new.list > /dev/null 2>&1; python3 -I $H/lane2.py run spnew $LN/new.list > /dev/null 2>&1; python3 -I $H/lane2.py run spnew $LN/new.list --mem > /dev/null 2>&1
python3 -I $H/lane2.py cmp integ sp $LN/tests.list $P/integ > $W/lane_cmp_sp.txt 2>&1
cp $LN/c/*.json $W/ 2>/dev/null; $H/save.sh > /dev/null 2>&1; log ALLDONE
