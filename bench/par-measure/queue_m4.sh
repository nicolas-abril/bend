#!/usr/bin/env bash
# The M4 measurement queue of this study, in order; every run waits for the
# 1-minute load to fall under 3 (at most 30 min, then it runs anyway and the
# load is on its line).
set -u
T=/private/tmp/bend-opt/par-tools/bench/par-measure; W=/private/tmp/bend-opt/par-work; cd $W
G="--max-load 3 --max-wait 1800"
B=bin; C=cnt; X=bt/bin
# 1. forked binarytrees: builds, drafts, wait edits, twins
python3 $T/ab.py --out bt_focus.jsonl --rounds 5 $G \
  main=$B/main/koru-par__binarytrees seq=$B/main/koru-seq__binarytrees \
  p2164=$B/p2164/koru-par__binarytrees p2183=$B/p2183/koru-par__binarytrees \
  int=$B/int/koru-par__binarytrees r2207=$B/r2207/koru-par__binarytrees \
  w_noyield=$X/bt_wait_noyield w_spin=$X/bt_wait_spin w_y16=$X/bt_wait_y16 \
  "tw_seq=tw/bt_twin seq {n}" "tw_spin=tw/bt_twin spin {n}" "tw_cond=tw/bt_twin cond {n}" \
  "tw_cond2=tw/bt_twin cond2 {n}" "tw_gcd=tw/bt_twin gcd {n}"
# 2. issue #2141's repro
python3 $T/ab.py --out fw_focus.jsonl --rounds 3 --threads 1,2,4,8,def,16 $G \
  main=$B/main/x__fork_wake_par seq=$B/main/x__fork_wake_seq p2164=$B/p2164/x__fork_wake_par \
  w_noyield=$X/fw_wait_noyield w_spin=$X/fw_wait_spin
# 3. granularity: the port's cutoff, on main and #2164
python3 $T/ab.py --out cut_focus.jsonl --rounds 3 --threads 1,4,def $G \
  $(for b in main p2164; do for c in 0 1 2 3 5 6 8 13; do echo "${b}_cut$c=$X/${b}_cut$c"; done; done)
# 4. counted builds against their plain twins (the counters must not move the run)
python3 $T/ab.py --out cnt_check.jsonl --rounds 5 --threads 1,def $G \
  bt_plain=$C/bt_main.plain bt_cnt=$C/bt_main.cnt fw_plain=$C/fw_main.plain fw_cnt=$C/fw_main.cnt
for b in main p2164 p2183 int r2207; do for t in 1 4 def; do for r in 1 2 3; do
  for p in bt fw; do
    python3 -c "import sys; sys.path.insert(0,'$T'); from scale import wait_quiet; wait_quiet(3,1800,False)"
    a=$([ $t = def ] && echo "" || echo "--threads $t")
    echo "{\"prog\":\"$p\",\"build\":\"$b\",\"threads\":\"$t\",\"load\":$(sysctl -n vm.loadavg | awk '{print $2}')}" >> cnt_runs.jsonl
    PAR_COUNT_OUT=$W/cnt_runs.jsonl $C/${p}_$b.cnt +RTS $a --gpu off -RTS > /dev/null
  done; done; done; done
# 5. Metal
python3 $T/gpu.py run gpu --rounds 5 --out gpu_run.jsonl
python3 $T/gpu.py split gpu --rounds 3 --out gpu_split.jsonl
# 6. the scaling matrix
PAR_SRC=/private/tmp/bend-opt/par-main python3 $T/scale.py run --builds main,int,r2207 \
  --threads 1,2,4,8,def --rounds 3 $G -v --out scale1.jsonl
echo QUEUE DONE
