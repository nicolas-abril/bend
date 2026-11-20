#!/bin/sh
# the built changes: main vs opt/queens (sink), integration vs integration+sink, #2177 vs #2177+early
Q=/private/tmp/bend-opt/pq-work
while pgrep -f "swp.py --rts --rounds 1 --out $Q/qsweep1.jsonl" > /dev/null; do sleep 30; done
exec python3 $Q/tools/swp.py --rts --rounds 2 --out $Q/qsweep2.jsonl --wdir $Q/swp2 \
  main=$Q/qe/qm_base.c:WL_FID_solve sink=$Q/sink/qs2.c:WL_FID_solve \
  int=$Q/qe/qi_base.c:WL_FID_solve int_sink=$Q/sink/qsi.c:WL_FID_solve \
  p2177=$Q/early/qb.c:WL_FID_solve p2177_early=$Q/early/qe.c:WL_FID_solve
