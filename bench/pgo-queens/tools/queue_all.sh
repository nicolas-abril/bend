#!/bin/sh
# queue_all.sh: every measurement of the study, one at a time; each result
# file is committed to bench/pgo-queens/results/ and pushed when its step ends.
Q=/private/tmp/bend-opt/pq-work
G=/private/tmp/bend-opt/pgoq
R=$G/bench/pgo-queens/results
mkdir -p $R
save() {  # save MESSAGE FILES..
  m=$1; shift
  cp "$@" $R/
  (cd $G && git add bench/pgo-queens/results && git commit -q -m "bench/pgo-queens: $m

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>" && git push -q https://github.com/nicolas-abril/bend.git bench/pgo-queens)
}
cd $Q
step=${1:-all}
if [ $step = all ] || [ $step = built ]; then
  sh $Q/tools/qsweep2.sh; python3 tools/swp.py --table qsweep2.jsonl > qsweep2.md
  save "results: queens, the sink and early against their bases" qsweep2.jsonl qsweep2.md
fi
if [ $step = all ] || [ $step = ladder ]; then
  OUT=$Q/qsweep1.jsonl sh $Q/tools/qsweep.sh; python3 tools/swp.py --table qsweep1.jsonl > qsweep1.md
  save "results: queens ladder, hand edits, respellings" qsweep1.jsonl qsweep1.md
fi
if [ $step = all ] || [ $step = prep ]; then
  (cd pgo && python3 pgo.py prep > prep.jsonl 2>&1)
  save "results: PGO builds (prep)" pgo/prep.jsonl
  (cd pgo && python3 pgo.py once --out once1.jsonl --rounds 1)
  save "results: PGO instruction pass" pgo/once1.jsonl
fi
if [ $step = all ] || [ $step = part1 ]; then
  (cd pgo && sh queue1.sh; python3 pgo.py summary sweep1.jsonl > summary1.md; python3 pgo.py table sweep1.jsonl > table1.md)
  save "results: Part 1 sweeps" pgo/sweep1.jsonl pgo/summary1.md pgo/table1.md
fi
if [ $step = all ] || [ $step = hints ]; then
  for p in symreg lexer; do for b in main int; do
    python3 $Q/qe/expect.py $Q/pgo/w/$p/$b/ms/x.c $Q/qe/${p}_${b}_expect.c 2> /dev/null
  done; done
  sh $Q/tools/qsweep3.sh; python3 tools/swp.py --table qsweep3.jsonl > qsweep3.md
  save "results: static hints against plain" qsweep3.jsonl qsweep3.md
fi
echo QUEUE DONE
