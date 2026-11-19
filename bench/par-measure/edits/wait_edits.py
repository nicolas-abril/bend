#!/usr/bin/env python3
"""Hand edits of the pool's wait in bend's emitted C (main's POOL_WAIT).

    wait_edits.py IN.c OUT.c MODE

MODE:
  noyield  the wait sleeps at once (no sched_yield loop)
  spin     the wait busy-spins on its condition and never sleeps; the turn
           still broadcasts (to nobody asleep): the bound of what sleeping
           and waking cost, paid for with cores that never idle
  y<N>     N sched_yield calls instead of 128
"""
import sys

OLD = """#define POOL_WAIT(c, cv) \\
  for (u32 s = 0; s < 128 && (c); s += 1) { \\
    sched_yield(); \\
  } \\
  pthread_mutex_lock(&pool_lock); \\
  while (c) { \\
    pthread_cond_wait(&cv, &pool_lock); \\
  } \\
  pthread_mutex_unlock(&pool_lock);
"""

src = open(sys.argv[1]).read()
mode = sys.argv[3]
assert src.count(OLD) == 1, "POOL_WAIT not found"
if mode == "noyield":
    new = OLD.replace("s < 128", "s < 0")
elif mode == "spin":
    new = "#define POOL_WAIT(c, cv) \\\n  while (c) { __asm__ volatile(\"yield\"); }\n"
elif mode.startswith("y"):
    new = OLD.replace("s < 128", "s < " + mode[1:])
else:
    raise SystemExit("unknown mode")
open(sys.argv[2], "w").write(src.replace(OLD, new))
