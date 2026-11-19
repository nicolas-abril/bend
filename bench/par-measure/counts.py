#!/usr/bin/env python3
"""Summarise counter dumps (one JSON line a run, from a -DPAR_COUNT build).

    counts.py FILE [FILE...]   one row per dump line

Times are in microseconds. Columns:
  wall: constructor to exit; cube: inside cube_run (the parallel part, from
  the first fork that left the main thread); turns g/d: grow and drain turns;
  turn us: mean drain turn; work/turn: the threads' busy time per drain turn;
  max/turn: the busiest thread's busy time per drain turn; eff: drain work /
  (threads x drain wall); tasks: monk tasks run (seq: in a drain's sequential
  mode); call/cont/join: task nodes made (a call to a fork-free def or a
  fork's child; a continuation as a heap task; a fork's join); P%: share of
  task time that started on a performance core; yields, cwaits: the waits'
  sched_yield and pthread_cond_wait calls; idle: the threads' waiting time.
"""
import json, sys


def summary(d):
    ns = d["tick_ns"] / 1000.0
    pt = d["per_thread"]
    tot = {k: sum(p[k] for p in pt) for k in pt[0] if k != "hist"}
    hist = [sum(p["hist"][i] for p in pt) for i in range(24)]
    td = max(d["turns_drain"], 1)
    tk = tot["task_ticks_p"] + tot["task_ticks_e"]
    return {
        "threads": d["threads"],
        "wall_us": d["wall_ticks"] * ns,
        "cube_us": d["cube_ticks"] * ns,
        "turns_grow": d["turns_grow"],
        "turns_drain": d["turns_drain"],
        "grow_turn_us": d["turn_ticks_grow"] * ns / max(d["turns_grow"], 1),
        "drain_turn_us": d["turn_ticks_drain"] * ns / td,
        "drain_work_per_turn_us": d["turn_work_drain"] * ns / td,
        "drain_max_per_turn_us": d["turn_max_drain"] * ns / td,
        "drain_eff": d["turn_work_drain"] / max(d["threads"] * d["turn_ticks_drain"], 1),
        "tasks": tot["monk"], "tasks_seq": tot["monk_seq"],
        "task_us_total": tk * ns,
        "task_call": tot["task_call"], "task_cont": tot["task_cont"],
        "task_join": tot["task_join"], "push": tot["push"], "deal": tot["deal"],
        "pcore_pct": 100.0 * tot["task_ticks_p"] / max(tk, 1),
        "yields": tot["yields"], "cond_waits": tot["cond_waits"],
        "idle_us": tot["wait_ticks"] * ns,
        "row_grow": tot["row_grow"], "row_grow_passes": tot["row_grow_passes"],
        "claims": tot["claims"],
        # task length histogram: bucket i holds tasks of 2^i to 2^(i+1) ticks
        "task_hist_us": {f"{(2**i)*ns:.3g}": hist[i] for i in range(24) if hist[i]},
    }


if __name__ == "__main__":
    for f in sys.argv[1:]:
        for line in open(f):
            line = line.strip()
            if line.startswith("{"):
                s = summary(json.loads(line))
                print(json.dumps({k: (round(v, 2) if isinstance(v, float) else v)
                                  for k, v in s.items()}))
