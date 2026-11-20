#!/usr/bin/env bash
# The M4 measurement queue of this study, in the order of its priorities.
# Every run waits until other processes use under 2.5 cores (ps %CPU outside
# this run's process group) and is redone (up to 5 times) when they used more
# before or after it; each line carries the load average and the others' use.
# Run it under ~/Software/supgen-bend/limit SECONDS 10240.
set -u
T=/private/tmp/bend-opt/par-tools/bench/par-measure; W=/private/tmp/bend-opt/par-work; cd $W
G="--max-load 2.5 --max-wait 10800"
B=bin; C=cnt; X=bt/bin
step() { echo "STEP $1 $(date +%H:%M) load $(sysctl -n vm.loadavg)"; }
# 1-2. the scaling matrix: every program, main, opt/integration, #2207
step matrix
PAR_SRC=/private/tmp/bend-opt/par-main python3 $T/scale.py run --builds main,int,r2207 \
  --threads 1,2,4,8,def --rounds 3 $G -v --out scale1.jsonl > scale1.log 2>&1
# 3. forked binarytrees: builds, drafts, wait edits, twins; cutoffs; #2141's repro
step bt
python3 $T/ab.py --out bt_focus.jsonl --rounds 5 $G \
  main=$B/main/koru-par__binarytrees seq=$B/main/koru-seq__binarytrees \
  p2164=$B/p2164/koru-par__binarytrees p2183=$B/p2183/koru-par__binarytrees \
  int=$B/int/koru-par__binarytrees r2207=$B/r2207/koru-par__binarytrees \
  w_noyield=$X/bt_wait_noyield w_spin=$X/bt_wait_spin w_y16=$X/bt_wait_y16 \
  "tw_seq=tw/bt_twin seq {n}" "tw_spin=tw/bt_twin spin {n}" "tw_cond=tw/bt_twin cond {n}" \
  "tw_cond2=tw/bt_twin cond2 {n}" "tw_gcd=tw/bt_twin gcd {n}"
step cut
python3 $T/ab.py --out cut_focus.jsonl --rounds 3 --threads 1,4,def $G \
  $(for b in main p2164; do for c in 0 1 2 3 5 6 8 13; do echo "${b}_cut$c=$X/${b}_cut$c"; done; done)
step fw
python3 $T/ab.py --out fw_focus.jsonl --rounds 3 --threads 1,2,4,8,def,16 $G \
  main=$B/main/x__fork_wake_par seq=$B/main/x__fork_wake_seq p2164=$B/p2164/x__fork_wake_par \
  w_noyield=$X/fw_wait_noyield w_spin=$X/fw_wait_spin
step cnt_check
python3 $T/ab.py --out cnt_check.jsonl --rounds 5 --threads 1,def $G \
  bt_plain=$C/bt_main.plain bt_cnt=$C/bt_main.cnt fw_plain=$C/fw_main.plain fw_cnt=$C/fw_main.cnt
step counted
counted() {  # counted LABEL BINARY THREADS (one unrecorded warm run first)
  PAR_COUNT_OUT=/dev/null $2 +RTS --gpu off -RTS > /dev/null 2>&1
  for i in 1 2 3 4 5 6; do
    python3 -c "import sys; sys.path.insert(0,'$T'); from scale import wait_quiet; wait_quiet(2.5,10800,False)"
    b=$(python3 -c "import sys; sys.path.insert(0,'$T'); from scale import others_cpu; print(others_cpu())")
    a=$([ $3 = def ] && echo "" || echo "--threads $3")
    PAR_COUNT_OUT=$W/cnt_tmp.json $2 +RTS $a --gpu off -RTS > /dev/null
    e=$(python3 -c "import sys; sys.path.insert(0,'$T'); from scale import others_cpu; print(others_cpu())")
    if python3 -c "import sys; sys.exit(0 if max($b,$e) <= 2.5 else 1)"; then
      echo "{\"label\":\"$1\",\"threads\":\"$3\",\"load\":$(sysctl -n vm.loadavg | awk '{print $2}'),\"others\":$b,\"others_after\":$e,\"count\":$(tail -1 $W/cnt_tmp.json)}" >> cnt_runs.jsonl
      rm -f $W/cnt_tmp.json; return
    fi
    rm -f $W/cnt_tmp.json
  done
}
for r in 1 2 3; do for t in 1 4 def; do for b in main p2164 p2183 int r2207; do
  counted bt_$b $C/bt_$b.cnt $t; counted fw_$b $C/fw_$b.cnt $t; done; done; done
# 4. Metal; the multi-turn benches' barrier (counted) and their wait edits
step gpu
python3 $T/gpu.py run gpu --rounds 5 --out gpu_run.jsonl
python3 $T/gpu.py split gpu --rounds 3 --out gpu_split.jsonl
step multiturn
for r in 1 2 3; do for p in histogram tree-bitonic kmeans tree-radix; do
  counted mt_$p $C/main/bench__$p.cnt def; done; counted mt_pure_par_sort $C/main/demo__pure_par_sort.cnt def; done
python3 $T/ab.py --out mt_focus.jsonl --rounds 3 --threads 4,def,16 $G \
  $(for p in histogram tree-bitonic kmeans; do echo "${p}=$B/main/bench__$p ${p}_noyield=mt/${p}_noyield ${p}_spin=mt/${p}_spin"; done) \
  pps=$B/main/demo__pure_par_sort pps_noyield=mt/pure_par_sort_noyield pps_spin=mt/pure_par_sort_spin
# 5. kmeans PAR-CPU at the gate's thread count, against the compiler of its pin
step kmeans
python3 $T/ab.py --out km_focus.jsonl --rounds 5 --threads 1,8,def,16 $G \
  main=$B/main/bench__kmeans pin386b7fc1=km/kmeans_pin_ownsrc
for r in 1 2 3; do counted km_main km/kmeans_main.cnt 16; counted km_main km/kmeans_main.cnt def; done
step done
echo QUEUE DONE
