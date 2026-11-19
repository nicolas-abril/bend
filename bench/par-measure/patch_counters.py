#!/usr/bin/env python3
"""Patch per-thread counters into the C that bend emits.

    patch_counters.py IN.c OUT.c

Build OUT.c with -DPAR_COUNT to count; without it the inserted macros are
empty and the C is the plain runtime (check that the two builds match in
wall time and context switches before trusting counts). Every counter is a
plain add to the calling thread's own 256-byte slot (no shared atomics);
the thread is found from its Env (`e.alc` is the thread's row of ALC) on
hot paths and from a thread-local on the pool's paths. At exit one JSON
line goes to $PAR_COUNT_OUT (default: stderr):

  per thread: tasks by kind (task_node with rem 0: a call task or a fork's
  child; rem 1: a continuation that is a heap task instead of a stack
  frame; rem >= 2: a fork's join), ring pushes, deals, monk tasks run (and
  how many in sequential mode), ticks inside work_loop split by the core it
  started on (CPUs 0-5 are the M4's efficiency cores, 6-9 performance), a
  log2 histogram of task ticks, row_grow calls and passes, pool claims and
  the ticks inside them, yields and condition waits and the ticks spent
  waiting;
  per program: grow and drain turns, the main thread's ticks inside turns
  and inside cube_run, and per turn the work done (sum of the threads' busy
  ticks) and the busiest thread's share, aggregated.

With BEND_METAL, also the GPU's split: gpu_probe and gpu_load (pipeline
from the .gpu archive) ticks, gpu_pass calls and their ticks, command
buffers, host ticks in waitUntilCompleted, the GPU's own busy seconds
(sum of GPUEndTime - GPUStartTime) and when the first and last pass ran.

Ticks are cntvct_el0, read at cntfrq_el0 (1 GHz on the M4, advancing in
steps of about 41.7 ns); the dump gives tick_ns.
"""
import re, sys

HEAD = r'''
// ---- par-measure counters (patch_counters.py) ----
#if !DEVICE && defined(PAR_COUNT)
#include <stdio.h>
enum { PC_TASK0, PC_TASK1, PC_TASKJ, PC_PUSH, PC_DEAL, PC_MONK, PC_MONK_SEQ,
  PC_TK_P, PC_TK_E, PC_ROWGROW, PC_ROWGROW_IT, PC_CLAIMS, PC_BUSY, PC_YIELDS,
  PC_CWAITS, PC_WAIT_TK, PC_BIG_P, PC_BIG_E, PC_BIGTK_P, PC_BIGTK_E, PC_N };
static const char* PC_NAMES[] = { "task_call", "task_cont", "task_join", "push",
  "deal", "monk", "monk_seq", "task_ticks_p", "task_ticks_e", "row_grow",
  "row_grow_passes", "claims", "busy_ticks", "yields", "cond_waits",
  "wait_ticks", "big_p", "big_e", "big_ticks_p", "big_ticks_e" };
typedef struct { u64 v[PC_N]; u64 hist[24]; } __attribute__((aligned(256))) PcSlot;
static PcSlot pc_slot[CUBE_T];
static _Thread_local u32 pc_me;
static u64 pc_turns[2], pc_turn_tk[2], pc_turn_work[2], pc_turn_max[2],
  pc_turn_rows[2], pc_cube, pc_cube_tk, pc_t_start, pc_turn_small, pc_turn_hist[24];
static u64 pc_busy0[CUBE_T];
static u64 pc_gpu_probe, pc_gpu_load, pc_gpu_passes, pc_gpu_pass_tk, pc_gpu_cbs,
  pc_gpu_wait_tk, pc_gpu_first, pc_gpu_last;
static double pc_gpu_kernel_s;
static inline u64 pc_tick(void) {
  u64 v; __asm__ volatile("mrs %0, cntvct_el0" : "=r"(v)); return v;
}
static inline u32 pc_cpu(void) {
  u64 v; __asm__ volatile("mrs %0, tpidr_el0" : "=r"(v)); return v & 0xfff;
}
static inline u32 pc_log2(u64 x) { return x ? 63 - __builtin_clzll(x) : 0; }
#define PC_E(e) ((u32)(((u64*)(e).alc - &ALC[0][0]) / (3 * NCLS_ALL)))
#define PC_ADD(w, k, n) (pc_slot[w].v[k] += (n))
#define PC_ME(w) (pc_me = (w))
#define PC_TASK_BEGIN u64 pc_t0 = pc_tick(); u32 pc_c = pc_cpu();
#define PC_TASK_END(e, seq) do { u64 pc_d = pc_tick() - pc_t0; u32 pc_w = PC_E(e); \
    PcSlot* s = &pc_slot[pc_w]; s->v[PC_MONK] += 1; s->v[PC_MONK_SEQ] += (seq) != 0; \
    s->v[pc_c >= 6 ? PC_TK_P : PC_TK_E] += pc_d; \
    s->hist[pc_log2(pc_d) < 23 ? pc_log2(pc_d) : 23] += 1; \
    if (pc_d >= PC_BIG) { s->v[pc_c >= 6 ? PC_BIG_P : PC_BIG_E] += 1; \
      s->v[pc_c >= 6 ? PC_BIGTK_P : PC_BIGTK_E] += pc_d; } } while (0)
#ifndef PC_BIG
#define PC_BIG 32768
#endif
#define PC_TURN_BEGIN u64 pc_t0 = pc_tick(); \
  for (u32 i = 0; i < pool_size; i += 1) pc_busy0[i] = pc_slot[i].v[PC_BUSY];
#define PC_TURN_END(grow, rows) do { u64 pc_d = pc_tick() - pc_t0, w = 0, m = 0; \
    for (u32 i = 0; i < pool_size; i += 1) { u64 b = pc_slot[i].v[PC_BUSY] - pc_busy0[i]; \
      w += b; m = b > m ? b : m; } \
    pc_turns[grow] += 1; pc_turn_tk[grow] += pc_d; pc_turn_work[grow] += w; \
    pc_turn_max[grow] += m; pc_turn_rows[grow] += (rows); \
    pc_turn_hist[pc_log2(pc_d) < 23 ? pc_log2(pc_d) : 23] += 1; } while (0)
#define PC_CUBE_BEGIN u64 pc_c0 = pc_tick();
#define PC_CUBE_END do { pc_cube += 1; pc_cube_tk += pc_tick() - pc_c0; } while (0)
static void pc_dump(void) {
  const char* path = getenv("PAR_COUNT_OUT");
  FILE* f = path ? fopen(path, "a") : stderr;
  if (!f) return;
  u64 frq; __asm__ volatile("mrs %0, cntfrq_el0" : "=r"(frq));
  fprintf(f, "{\"threads\":%u,\"wall_ticks\":%llu,\"tick_ns\":%.4f,\"turns_grow\":%llu,"
    "\"turns_drain\":%llu,\"turn_ticks_grow\":%llu,\"turn_ticks_drain\":%llu,"
    "\"turn_work_grow\":%llu,\"turn_work_drain\":%llu,\"turn_max_grow\":%llu,"
    "\"turn_max_drain\":%llu,\"turn_rows_grow\":%llu,\"turn_rows_drain\":%llu,"
    "\"cube_runs\":%llu,\"cube_ticks\":%llu,\"turn_hist\":[",
    pool_size, (unsigned long long)(pc_tick() - pc_t_start), 1e9 / frq,
    pc_turns[1], pc_turns[0], pc_turn_tk[1], pc_turn_tk[0], pc_turn_work[1],
    pc_turn_work[0], pc_turn_max[1], pc_turn_max[0], pc_turn_rows[1],
    pc_turn_rows[0], pc_cube, pc_cube_tk);
  for (int i = 0; i < 24; i++) fprintf(f, "%s%llu", i ? "," : "", pc_turn_hist[i]);
  fprintf(f, "],\"gpu_probe_ticks\":%llu,\"gpu_load_ticks\":%llu,\"gpu_passes\":%llu,"
    "\"gpu_pass_ticks\":%llu,\"gpu_cmdbufs\":%llu,\"gpu_wait_ticks\":%llu,"
    "\"gpu_busy_s\":%.6f,\"gpu_first_at\":%llu,\"gpu_last_at\":%llu",
    pc_gpu_probe, pc_gpu_load, pc_gpu_passes, pc_gpu_pass_tk, pc_gpu_cbs,
    pc_gpu_wait_tk, pc_gpu_kernel_s, pc_gpu_first ? pc_gpu_first - pc_t_start : 0,
    pc_gpu_last ? pc_gpu_last - pc_t_start : 0);
  fprintf(f, ",\"per_thread\":[");
  for (u32 w = 0; w < pool_size; w += 1) {
    fprintf(f, "%s{", w ? "," : "");
    for (int k = 0; k < PC_N; k++) fprintf(f, "%s\"%s\":%llu", k ? "," : "", PC_NAMES[k],
      (unsigned long long)pc_slot[w].v[k]);
    fprintf(f, ",\"hist\":[");
    for (int i = 0; i < 24; i++) fprintf(f, "%s%llu", i ? "," : "", pc_slot[w].hist[i]);
    fprintf(f, "]}");
  }
  fprintf(f, "]}\n");
  if (path) fclose(f);
}
__attribute__((constructor)) static void pc_init(void) {
  pc_t_start = pc_tick();
  atexit(pc_dump);
}
#else
#define PC_ADD(w, k, n) ((void)0)
#define PC_ME(w) ((void)0)
#define PC_TASK_BEGIN
#define PC_TASK_END(e, seq) ((void)0)
#define PC_TURN_BEGIN
#define PC_TURN_END(grow, rows) ((void)0)
#define PC_CUBE_BEGIN
#define PC_CUBE_END ((void)0)
#endif
#if !DEVICE && defined(PAR_COUNT)
#define PC_GPU(x) x
#else
#define PC_GPU(x)
#endif
// ---- end of counters ----
'''

GPU_EDITS = [
    ("  const char* why = gpu != 0 && BANGS != 0 ? gpu_probe() : \"\";\n",
     "  PC_GPU(u64 pc_g0 = pc_tick();)\n  const char* why = gpu != 0 && BANGS != 0 ? gpu_probe() : \"\";\n"
     "  PC_GPU(pc_gpu_probe = pc_tick() - pc_g0;)\n"),
    ("    gpu_load(size);\n",
     "    PC_GPU(u64 pc_g0 = pc_tick();)\n    gpu_load(size);\n    PC_GPU(pc_gpu_load = pc_tick() - pc_g0;)\n"),
    ("      gpu_pass(H);\n",
     "      PC_GPU(u64 pc_g0 = pc_tick(); if (!pc_gpu_first) pc_gpu_first = pc_g0;)\n      gpu_pass(H);\n"
     "      PC_GPU(pc_gpu_last = pc_tick(); pc_gpu_passes += 1; pc_gpu_pass_tk += pc_gpu_last - pc_g0;)\n"),
    ("      [c waitUntilCompleted];\n",
     "      PC_GPU(u64 pc_w0 = pc_tick();)\n      [c waitUntilCompleted];\n"
     "      PC_GPU(pc_gpu_wait_tk += pc_tick() - pc_w0; if (c) { pc_gpu_cbs += 1;"
     " pc_gpu_kernel_s += c.GPUEndTime - c.GPUStartTime; })\n"),
]

# (pattern, replacement, required); patterns are literal unless they start
# with "re:". Each must match exactly once when required.
EDITS = [
    ("#define ring_word(H, r, w)", HEAD + "\n#define ring_word(H, r, w)", True),
    ("INLINE u64 task_node(Env e, u32 fid, Term cont, u32 idx, u32 rem) {\n",
     "INLINE u64 task_node(Env e, u32 fid, Term cont, u32 idx, u32 rem) {\n"
     "  PC_ADD(PC_E(e), rem == 0 ? PC_TASK0 : rem == 1 ? PC_TASK1 : PC_TASKJ, 1);\n", True),
    ("re:(INLINE (?:void|bool) ring_push\\(DEV u64\\* H, u32 r, Term tsk\\) \\{\n)",
     "\\1  PC_ADD(pc_me, PC_PUSH, 1);\n", True),
    ("INLINE void task_deal(DEV u64* H, Term join, u32 base, u32 stride, TG u32* cur) {\n",
     "INLINE void task_deal(DEV u64* H, Term join, u32 base, u32 stride, TG u32* cur) {\n"
     "  PC_ADD(pc_me, PC_DEAL, 1);\n", True),
    ("    Term r = work_loop(e, stk, t, seq);\n",
     "    PC_TASK_BEGIN\n    Term r = work_loop(e, stk, t, seq);\n    PC_TASK_END(e, seq);\n", True),
    ("    bool slow = io_tick() > end;\n",
     "    bool slow = io_tick() > end;\n    PC_ADD(pc_me, PC_ROWGROW_IT, 1);\n", True),
    ("re:(static u32 row_grow\\(Env e, DEV Term\\* stk, u32 base, u32 stride, u32 want,\n  u32 rows(?:, u32\\* ready)?\\) \\{\n)",
     "\\1  PC_ADD(pc_me, PC_ROWGROW, 1);\n", True),
    # main's wait: yields, then a condition wait
    ("re:#define POOL_WAIT\\(c, cv\\) \\\\\n  for \\(u32 s = 0; s < 128 && \\(c\\); s \\+= 1\\) \\{ \\\\\n    sched_yield\\(\\); \\\\\n  \\} \\\\\n  pthread_mutex_lock\\(&pool_lock\\); \\\\\n  while \\(c\\) \\{ \\\\\n    pthread_cond_wait\\(&cv, &pool_lock\\); \\\\\n  \\} \\\\\n  pthread_mutex_unlock\\(&pool_lock\\);\n",
     "#define POOL_WAIT(c, cv) \\\n  { PC_TASK_WAIT_BEGIN \\\n  for (u32 s = 0; s < 128 && (c); s += 1) { \\\n"
     "    sched_yield(); PC_ADD(pc_me, PC_YIELDS, 1); \\\n  } \\\n  pthread_mutex_lock(&pool_lock); \\\n"
     "  while (c) { \\\n    PC_ADD(pc_me, PC_CWAITS, 1); pthread_cond_wait(&cv, &pool_lock); \\\n  } \\\n"
     "  pthread_mutex_unlock(&pool_lock); PC_TASK_WAIT_END }\n", False),
    # #2164's wait: spins, then a condition wait
    ("  for (u32 spins = 4096; spins && !a32_load(pending); spins -= 1) {}\n",
     "  PC_TASK_WAIT_BEGIN\n  for (u32 spins = 4096; spins && !a32_load(pending); spins -= 1) { PC_ADD(pc_me, PC_YIELDS, 1); }\n", False),
    ("    pthread_cond_wait(&pool_wake[w], &pool_lock);\n",
     "    PC_ADD(pc_me, PC_CWAITS, 1); pthread_cond_wait(&pool_wake[w], &pool_lock);\n", False),
    ("  a32_store(pending, 0);\n  pthread_mutex_unlock(&pool_lock);\n",
     "  a32_store(pending, 0);\n  pthread_mutex_unlock(&pool_lock);\n  PC_TASK_WAIT_END\n", False),
    ("    a32_acq(&pool_row);\n", "    a32_acq(&pool_row);\n    PC_TASK_BEGIN\n", True),
    ("    n += 1;\n  }\n}\n",
     "    PC_ADD(pc_me, PC_BUSY, pc_tick() - pc_t0); PC_ADD(pc_me, PC_CLAIMS, 1);\n    n += 1;\n  }\n}\n", True),
    ("re:(static void\\* pool_work\\(void\\* arg\\) \\{\n.*?pool_stack\\(\\);\n)",
     "\\1  PC_ME((uintptr_t)arg);\n", True),
    ("OUTLINE void pool_turn(bool grow, u32 rows) {\n",
     "OUTLINE void pool_turn(bool grow, u32 rows) {\n  PC_TURN_BEGIN\n", True),
    ("static void cube_run(u64* H, bool gpu) {\n",
     "static void cube_run(u64* H, bool gpu) {\n  PC_CUBE_BEGIN\n", True),
    ("  a32_store(a32_at(H, H_CURSOR), 0);\n}\n",
     "  a32_store(a32_at(H, H_CURSOR), 0);\n  PC_CUBE_END;\n}\n", True),
]

WAIT_MACROS = r'''
#if !DEVICE && defined(PAR_COUNT)
#define PC_TASK_WAIT_BEGIN u64 pc_wt0 = pc_tick();
#define PC_TASK_WAIT_END PC_ADD(pc_me, PC_WAIT_TK, pc_tick() - pc_wt0);
#else
#define PC_TASK_WAIT_BEGIN
#define PC_TASK_WAIT_END
#endif
'''


def patch(src):
    src = src.replace(HEAD.strip()[:0], "")
    for pat, rep, req in EDITS:
        if pat.startswith("re:"):
            new, n = re.subn(pat[3:], rep, src, flags=re.S if "pool_work" in pat else 0)
        else:
            n = src.count(pat)
            new = src.replace(pat, rep)
        if n > 1 or (req and n != 1):
            raise SystemExit(f"patch_counters: {pat[:60]!r} matched {n} times")
        src = new
    for pat, rep in GPU_EDITS:
        if src.count(pat) > 1:
            raise SystemExit(f"patch_counters: {pat[:60]!r} matched more than once")
        src = src.replace(pat, rep)
    src = src.replace("// ---- end of counters ----", WAIT_MACROS + "// ---- end of counters ----", 1)
    # pool_turn's end: PC_TURN_END before its closing brace (the wait is last)
    m = re.search(r"OUTLINE void pool_turn\(bool grow, u32 rows\) \{\n(.*?)\n\}\n", src, re.S)
    body = m.group(1)
    src = src[:m.end(1)] + "\n  PC_TURN_END(grow, rows);" + src[m.end(1):]
    return src


if __name__ == "__main__":
    s = open(sys.argv[1]).read()
    open(sys.argv[2], "w").write(patch(s))
