# par-measure

Tools for measuring bend's parallel lanes (CPU threads and Metal). Not a
gate; not in `gates/repo.ts`' allow list. Work in progress; see the end of
this file for what each tool does.

- `tm.c`: runs a command, prints wall, user, sys, context switches, peak
  RSS, instructions and cycles, the performance-core share and runnable time.
- `build.sh`: emits a program's C with a given bend checkout and builds it
  as the perf gate's CPU cells do (`BEND_GPU=1`: `bend -o`, with the .gpu).
- `progs.py`: the programs (17 benches, 17 koru forked ports and their
  sequential twins, the forking demos, #2141's repro).
- `scale.py`: builds every program per build, runs the thread-scaling
  matrix interleaved, prints tables.
- `patch_counters.py`: per-thread counters patched into the emitted C,
  active with `-DPAR_COUNT`; `counts.py` summarises their dumps.
