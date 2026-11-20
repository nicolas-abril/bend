#!/bin/sh
# setup.sh: rebuild every scratch input of this study under $Q
# (/private/tmp/bend-opt/pq-work) from worktrees at /private/tmp/bend-opt/:
#   pq-main (bendlang/bend main 0e2f38f7), pq-int (opt/integration 60c755f4),
#   pq-perc (bench/perceus 50e89cd6), p2177 (opt/call-site-returns 74a1c357),
#   pq (opt/queens), pqe (opt/queens-early), pq-int-sink (opt/integration, the
#   sink patch is applied here), pgoq (this branch).
set -eu
O=/private/tmp/bend-opt
Q=$O/pq-work
B=$O/pgoq/bench/pgo-queens
mkdir -p $Q/tools $Q/pgo $Q/q $Q/qe $Q/qt $Q/qr $Q/sink $Q/early $Q/adv $Q/adve
cp $B/tools/*.py $B/tools/*.sh $B/tools/tm.c $Q/tools/
cp $B/tools/pgo.py $B/tools/progs.py $B/tools/queue1.sh $Q/pgo/
cc -O2 $Q/tools/tm.c -o $Q/tools/tm
# Koka's C++ references (test/bench/cpp at b66091b2)
if [ ! -d $Q/koka/src/test/bench/cpp ]; then
  mkdir -p $Q/koka && cd $Q/koka
  git clone -q --filter=blob:none --sparse https://github.com/koka-lang/koka.git src
  cd src && git checkout -q b66091b2a5a7ea20c5ed9498ad1e1f03caee9589 && git sparse-checkout set test/bench/cpp
fi
QB=$O/pq-main/bench/runtime/queens/main.bend
emit() { bun $1/bend2/main.ts $2 -o $3 > /dev/null; }
# queens on main and integration, and the hand edits
emit $O/pq-main $QB $Q/q/qm.c
emit $O/pq-int $QB $Q/q/qi.c
cd $Q/qe
cp $B/edits/*.py .
cp ../q/qm.c qm_base.c; cp ../q/qi.c qi_base.c
for v in qm qi; do
  for e in sat rec sat,rec nofuel sat,rec,nofuel; do python3 edit.py ../q/$v.c ${v}_$(echo $e | tr , _).c $e; done
done
python3 early.py ../q/qi.c qi_early.c
python3 edit.py qi_early.c qi_early_rec.c rec
python3 expect.py ../q/qm.c qm_expect.c 2> /dev/null
# the ladder
cp $B/ladder/* $Q/qt/
# the respellings
cd $Q/qr
cp $B/respell/*.bend .
for r in r1 r2 r3; do emit $O/pq-main $r.bend ${r}_m.c; emit $O/pq-int $r.bend ${r}_i.c; done
# the sink: opt/queens, and opt/integration with its diff
emit $O/pq $QB $Q/sink/qs2.c
cd $O/pq-int-sink
if ! grep -q "function let_sink" bend2/comp.ts; then
  git -C $O/pq diff 0e2f38f7 HEAD -- bend2/comp.ts > $Q/sink/sink.patch
  git apply -3 $Q/sink/sink.patch || true
  python3 - <<'EOF'
p = 'bend2/comp.ts'
s = open(p).read()
if '<<<<<<< ours' in s:
    a = s.index('<<<<<<< ours\n'); b = s.index('>>>>>>> theirs\n') + len('>>>>>>> theirs\n')
    s = s[:a] + '''  const l = (x.$ === "Let" && args.length === 0 ? let_sink(x, ty) : null)
    ?? (x.$ === "Let" || (args.length === 0 && x.$ !== "Lam")
    ? (args.length === 0 && emit_deep(sc, x)) || anf(x, ty) : x);
''' + s[b:]
    open(p, 'w').write(s)
EOF
fi
emit $O/pq-int-sink $QB $Q/sink/qsi.c
# early on #2177
emit $O/p2177 $QB $Q/early/qb.c
emit $O/pqe $QB $Q/early/qe.c
# adversarial programs
cp $B/adversarial/s*.bend $B/adversarial/queens_small.bend $Q/adv/
cp $B/adversarial/e*.bend $Q/adve/
echo SETUP DONE
