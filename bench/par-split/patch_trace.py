#!/usr/bin/env python3
"""patch_trace.py IN.c OUT.c: patch a per-thread event trace into bend's emitted C.

Build OUT.c with -DPAR_TRACE (without it the C is the original runtime). At exit
the trace goes to $PAR_TRACE_OUT (read by trace.py): per thread, events
{u64 t0; u32 dur; u16 kind; u16 aux}. Kinds: 0 a monk_step task (aux: bit0
seq, bits1-2 result 0 none / 1 forked / 2 continuation, bit3 P-core, bits4-15
the task's fid), 1 a grow turn (aux rows), 2 a drain turn, 3 cube_run.
"""
import sys

HEAD = r'''
// ---- par trace (patch_trace.py) ----
#if !DEVICE && defined(PAR_TRACE)
#include <stdio.h>
typedef struct { u64 t0; u32 dur; u16 kind; u16 aux; } TrEv;
#define TR_CAP (1u << 22)
static TrEv* tr_buf[CUBE_T];
static u32 tr_n[CUBE_T];
static u64 tr_drop[CUBE_T];
static u64 tr_t_start;
static inline u64 tr_tick(void) { u64 v; __asm__ volatile("mrs %0, cntvct_el0" : "=r"(v)); return v; }
static inline u32 tr_pc(void) { u64 v; __asm__ volatile("mrs %0, tpidr_el0" : "=r"(v)); return (v & 0xfff) >= 6; }
static inline void tr_add(u32 w, u64 t0, u64 t1, u16 kind, u16 aux) {
  if (!tr_buf[w]) tr_buf[w] = (TrEv*)malloc(sizeof(TrEv) * TR_CAP);
  u64 d = t1 - t0;
  if (tr_n[w] < TR_CAP) tr_buf[w][tr_n[w]++] = (TrEv){ t0, d > 0xffffffffull ? 0xffffffffu : (u32)d, kind, aux };
  else tr_drop[w] += 1;
}
#define TR_W(e) ((u32)(((u64*)(e).alc - &ALC[0][0]) / (sizeof(ALC[0]) / 8)))
static void tr_dump(void) {
  const char* path = getenv("PAR_TRACE_OUT");
  if (!path) return;
  FILE* f = fopen(path, "wb");
  if (!f) return;
  u64 frq; __asm__ volatile("mrs %0, cntfrq_el0" : "=r"(frq));
  u32 hdr[2] = { 0x54524345u, pool_size };
  u64 h2[3] = { tr_t_start, tr_tick(), frq };
  fwrite(hdr, 4, 2, f); fwrite(h2, 8, 3, f);
  for (u32 w = 0; w < pool_size; w += 1) {
    fwrite(&tr_n[w], 4, 1, f); fwrite(&tr_drop[w], 8, 1, f);
    if (tr_n[w]) fwrite(tr_buf[w], sizeof(TrEv), tr_n[w], f);
  }
  fclose(f);
}
__attribute__((constructor)) static void tr_init(void) { tr_t_start = tr_tick(); atexit(tr_dump); }
#define TR_BEGIN u64 tr_t0 = tr_tick();
#define TR_END(w, kind, aux) tr_add((w), tr_t0, tr_tick(), (kind), (aux))
#define TR_PCORE tr_pc()
#else
#define TR_BEGIN
#define TR_END(w, kind, aux) ((void)0)
#define TR_PCORE 0
#endif
// ---- end of trace ----
'''

EDITS = [
    ("#define ring_word(H, r, w)", HEAD + "\n#define ring_word(H, r, w)"),
    ("    Term r = work_loop(e, stk, t, seq);\n",
     "    TR_BEGIN\n    u32 tr_fid = term_aux(t);\n    Term r = work_loop(e, stk, t, seq);\n"
     "    TR_END(TR_W(e), 0, (u16)((seq != 0) | ((r == 0 ? 0 : (u32)H[task_tail(r) + 1] != 0 ? 1 : 2) << 1) | (TR_PCORE << 3) | ((tr_fid & 0xFFF) << 4)));\n"),
    ("OUTLINE void pool_turn(bool grow, u32 rows) {\n", "OUTLINE void pool_turn(bool grow, u32 rows) {\n  TR_BEGIN\n"),
    ("  POOL_WAIT(a32_load_acq(&pool_done) != 0, pool_join)\n", "  POOL_WAIT(a32_load_acq(&pool_done) != 0, pool_join)\n  TR_END(0, grow ? 1 : 2, (u16)rows);\n"),
    ("static void cube_run(u64* H, bool gpu) {\n", "static void cube_run(u64* H, bool gpu) {\n  TR_BEGIN\n"),
    ("  a32_store(a32_at(H, H_CURSOR), 0);\n}\n", "  a32_store(a32_at(H, H_CURSOR), 0);\n  TR_END(0, 3, 0);\n}\n"),
]

if __name__ == "__main__":
    s = open(sys.argv[1]).read()
    for pat, rep in EDITS:
        if s.count(pat) != 1:
            raise SystemExit(f"patch_trace: {pat[:60]!r} matched {s.count(pat)} times")
        s = s.replace(pat, rep)
    open(sys.argv[2], "w").write(s)
