# Closure elimination: raw results

Scratch material for the closure-elimination draft (branch `opt/closure-elim`,
stacked on `opt/integration` bae64757), not for merging. Programs:
nicolas-abril/bend-benchmarks (the 230, plus `closures/` from 8056c4b).

- `results/meas.jsonl`: 5 interleaved runs at one thread (and one at 10 threads
  for parallel ports) of every program whose C differs, `int` = bae64757 and
  `elim` = this branch; `table2.md` the medians; `helpers.jsonl` the helper-def
  spellings of `closures/`.
- `results/sweeps.txt`, `sweeps_vs_helpers.jsonl`: 16-position placement sweeps,
  2 rounds, P-core cycles (eqsat `tools/swp.py`).
- `results/lane_*`: the native lane (1,107 tests, `int` against `elim2`), the
  memory check (`-DBEND_POISON`, live words at 1 and 8 threads) on the 67 changed
  tests; `wrong_versions.txt`: which tests catch each deliberately wrong version.
- `results/ctime*.txt`: emit wall time (bun), integration against this branch.
- `tools/`: the scripts (paths under /private/tmp/bend-opt/clo).
