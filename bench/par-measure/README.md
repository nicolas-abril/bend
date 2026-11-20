# par-measure

Tools for measuring bend's parallel lanes (CPU threads and Metal), written
for the 2026-11-19 study of where parallel speedup is lost. Not a gate; not
in `gates/repo.ts`' allow list. Paths default to /private/tmp/bend-opt/par-work
($PAR_WORK); every script prints its usage with -h or in its header.

## Tools

- `tm.c` (macOS): runs a command and prints one line: rc, wall, user, sys,
  voluntary and involuntary context switches, peak RSS, instructions,
  cycles, the performance-core share of instructions, cycles and time
  (RUSAGE_INFO_V6), and runnable time (threads ready but waiting for a
  core: the direct sign of other load). `tm_linux.c`: the same first keys.
- `build.sh ROOT SRC OUT`: emits SRC's C with the bend checkout ROOT and
  builds it as the perf gate's CPU cells do (`cc -std=c11 -O3 -lpthread`);
  `BEND_GPU=1` builds the user binary with `bend -o` (and its .gpu).
- `progs.py`: the programs: the 17 benches, the 17 forked koru ports and
  their sequential twins, the forking demos, #2141's repro
  (`progs/fork_wake_{par,seq}.bend`), and `progs/binarytrees_cut*.bend`
  (the forked binarytrees with its fork cutoff at 0..13 levels).
- `scale.py build|run|table`: builds every program per build and runs the
  thread-scaling matrix (1, 2, 4, 8, default threads), builds interleaved
  innermost, one JSON line a run. `--max-load N` pauses each run while
  other processes (outside the run's process group) use more than N cores.
- `ab.py`: the same for a list of LABEL=COMMAND variants (bend binaries or
  twins with `{n}` for the thread count); `--table` prints medians.
- `patch_counters.py IN.c OUT.c`: per-thread counters patched into the
  emitted C, active with `-DPAR_COUNT` (without it the C compiles to the
  same assembly as the original). Counts task nodes by kind, ring pushes,
  deals, tasks run (and in sequential mode), task time by the core type it
  started on, a task-length histogram, long tasks (the sequential stretches)
  by core type, row_grow passes, pool claims and busy time, yields,
  condition waits and wait time, grow and drain turns with their work and
  busiest thread, cube_run time; with BEND_METAL the GPU split (device
  probe, pipeline load, passes, command buffers, GPU busy time from
  GPUStartTime/GPUEndTime, host wait). `counts.py` summarises the dumps.
  `cnt_build.sh` / `cnt_metal.sh` patch and build (CPU / Metal).
- `edits/wait_edits.py`: hand edits of the pool's POOL_WAIT (no yields, a
  pure spin that never sleeps, N yields).
- `twins/bt_twin.c`: C twin of the forked binarytrees' fork tree under
  several pool designs (seq, spin, Bend's yield-then-sleep wait with one
  or two turns a tree, libdispatch).
- `gpu.py run|split DIR`: Metal wall times (a warm run first; the perf
  gate's GPU spans) and the counted split.
- `setup_m4.sh`: rebuilds every binary the queue needs from fresh worktrees.
- `report.py`: the scaling table (speedups over one thread and over the
  sequential twin) and the build comparison, from scale.py's runs.
- `queue_m4.sh`: the whole M4 queue in order (binarytrees variants, #2141's
  repro, the cutoffs, counted against plain, counted runs per build, Metal,
  the matrix), every run gated on other processes' CPU use.

## Notes for whoever runs them

- The M4's CPUs 0-5 are efficiency cores, 6-9 performance (from per-CPU
  speed; the CPU number is tpidr_el0 & 0xfff on this macOS). cntvct_el0
  runs at 1 GHz on the M4 but advances in steps of about 41.7 ns.
- A Metal binary's first run after a build pays seconds (3.6 s and 1.6 s on
  nbody) before it is warm (about 0.1 s); time warm runs.
- `results/`: raw outputs from 2026-11-19: three perf-gate runs on main
  0e2f38f7, the x86 (Ryzen 7 5800H laptop) runs, and one counted run of
  every forking program on main at the default thread count on a loaded M4
  (load 6 to 10: counts are good, times are not).
- `results/m4/` (2026-11-20, main 0e2f38f7, quiet M4, every run gated on
  other processes' CPU): the scaling matrix in three rounds
  (`scale_all.jsonl`, `scale_table_all.md`, `builds_table_all.md`; round 0
  is also in `results/m4_scale_round0_2026-11-20.jsonl`), forked
  binarytrees (`bt_focus`, `cut_focus`), counted runs (`cnt_runs.jsonl`:
  placement of the continuation, multi-turn turns), multi-turn wait edits
  (`mt_focus`), Metal (`gpu_run`, `gpu_split`; no CPU gate on those),
  kmeans against its pin commit (`km_focus`; `km_focus_v1` failed: the old
  binary takes its flags without +RTS), #2141's repro (`fw_focus`).
