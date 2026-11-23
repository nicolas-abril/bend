#!/usr/bin/env bash
# go_all.sh: the whole queue after a wipe, every heavy step through tools/heavy.sh, results
# pushed after each step: builds; the rest of the scaling curves; the 244 programs (integ, sp
# emitted; exit derived from integ) at 1 and 10 threads; the lane (integ, sp emitted; exit
# derived) and the memory check on the forking tests (exit, sp).
set -u
H=$(cd "$(dirname "$0")" && pwd); P=/private/tmp/bend-opt/par; W=$P/work; LN=$P/lane
log() { echo "$(date +%H:%M) $*" >> $W/go_all.log; }
mkdir -p $W $LN
log setup; $H/setup.sh > $P/setup.log 2>&1; log "setup done $(grep -c FAIL $P/setup.log) fails"
$H/go_ab.sh curves.jsonl main,integ,exit,sp 1,2,4,10 5 seam-carve suffix-array m-tiny m-sharedarr bt-par; log curves done
python3 -I $H/emit244.py $P/integ integ > $W/emit244_integ.txt 2>&1; log "244 integ emitted"
python3 -I $H/emit244.py $P/split sp > $W/emit244_sp.txt 2>&1; log "244 sp emitted"
python3 - <<PY
import os, re
W = "/private/tmp/bend-opt/par/b244"; os.makedirs(f"{W}/c/exit", exist_ok=True)
for f in os.listdir(f"{W}/c/integ"):
    if f.endswith(".c") and not f.endswith(".tmp.c"):
        c = open(f"{W}/c/integ/{f}").read().replace("seq = (seq & 1) | fid_nofk(wf) << 1;", "seq = (DEVICE ? seq & 1 : 0) | fid_nofk(wf) << 1;")
        open(f"{W}/c/exit/{f}", "w").write(c)
PY
for t in integ exit sp; do python3 -I $H/run244.py $t > $W/run244_$t.txt 2>&1; cp $P/b244/res/$t.jsonl $W/b244_$t.jsonl; $H/save.sh >/dev/null 2>&1; log "244 $t run"; done
python3 -I $H/lane2.py list $LN/tests.list $P/integ > /dev/null
python3 -I $H/lane2.py emit $P/integ integ $LN/tests.list > $LN/emit_integ.log 2>&1; log "lane integ emitted"
python3 -I $H/lane2.py derive integ exit $LN/tests.list 'seq = \(seq & 1\) \| fid_nofk\(wf\) << 1;=>seq = (DEVICE ? seq \& 1 : 0) | fid_nofk(wf) << 1;' >> $LN/emit_integ.log
python3 -I $H/lane2.py emit $P/split sp $LN/tests.list > $LN/emit_sp.log 2>&1; log "lane sp emitted"
grep -l 'if (!seq)' $LN/c/integ/*.c | xargs -n1 basename | sed 's/\.c$//' > $LN/forktests.txt
for t in integ exit sp; do python3 -I $H/lane2.py run $t $LN/tests.list > $LN/run_$t.log 2>&1; log "lane $t run"; done
for t in exit sp; do python3 -I $H/lane2.py run $t $LN/tests.list --mem --only $LN/forktests.txt > $LN/mem_$t.log 2>&1; log "mem $t run"; done
for t in exit sp; do python3 -I $H/lane2.py cmp integ $t $LN/tests.list $P/integ > $W/lane_cmp_$t.txt 2>&1; done
cp $LN/c/*.json $W/ 2>/dev/null; $H/save.sh > /dev/null 2>&1; log ALLDONE
