// L1: Bend's solve as C: its 16 parameters (precomputed bools z, e; the
// peeled sibling word and child words nc/nl/nr; the parent's cols/ld/rd;
// full; a Nat fuel; ret as a tagged Stats; sols, nodes). The child is a C
// call, the sibling a tail call (clang makes it a loop). u32 words.
// Rungs: -DNOFUEL drops the fuel; -DNORET passes the child's result in
// sols/nodes (no tag); -DNOPRE computes z and e in the callee.
#include "common.h"
typedef struct { uint32_t s, n; } R;
#ifdef NOFUEL
#define FUEL(x)
#define FP
#else
#define FUEL(x) x,
#define FP uint64_t f,
#endif
static R solve(FP uint32_t z, uint32_t e, uint32_t sib, uint32_t nc, uint32_t nl,
               uint32_t nr, uint32_t cols, uint32_t ld, uint32_t rd, uint32_t full,
               uint32_t rt, uint32_t rs, uint32_t rn, uint32_t sols, uint32_t nodes) {
  for (;;) {
#ifdef NOFUEL
    if (z) {
#else
    if (f == 0 || z) {
#endif
      if (rt == 0) return (R){sols, nodes};
      return (R){sols + rs, nodes + rn};
    }
#ifndef NOFUEL
    uint64_t g = f - 1;
#endif
    if (e) {
      uint32_t b2 = sib & (0u - sib), n2 = cols | b2;
      uint32_t s1 = rt ? sols + rs : sols, n1 = rt ? nodes + rn : nodes;
#ifndef NOFUEL
      f = g;
#endif
      z = sib == 0; e = n2 == full; nc = n2; nl = (ld | b2) << 1; nr = (rd | b2) >> 1;
      sib = sib - b2; rt = 0; rs = 0; rn = 0; sols = s1 + 1; nodes = n1 + 1;
      continue;
    }
    uint32_t cc = full & ~(nc | nl | nr), cb = cc & (0u - cc), cn = nc | cb;
    uint32_t b2 = sib & (0u - sib), n2 = cols | b2;
    uint32_t s1 = rt ? sols + rs : sols, n1 = rt ? nodes + rn : nodes;
    R w = solve(FUEL(g) cc == 0, cn == full, cc - cb, cn, (nl | cb) << 1, (nr | cb) >> 1,
                nc, nl, nr, full, 0, 0, 0, s1, n1 + 1);
#ifndef NOFUEL
    f = g;
#endif
    z = sib == 0; e = n2 == full; nc = n2; nl = (ld | b2) << 1; nr = (rd | b2) >> 1;
    sib = sib - b2;
#ifdef NORET
    rt = 0; rs = 0; rn = 0; sols = w.s; nodes = w.n;
#else
    rt = 1; rs = w.s; rn = w.n; sols = 0; nodes = 0;
#endif
  }
}
static Stats root(uint32_t c4, uint32_t l4, uint32_t r4, uint32_t full) {
  uint32_t cc = full & ~(c4 | l4 | r4), cb = cc & (0u - cc), cn = c4 | cb;
  R w = solve(FUEL((uint64_t)SIZE * SIZE) cc == 0, cn == full, cc - cb, cn,
              (l4 | cb) << 1, (r4 | cb) >> 1, c4, l4, r4, full, 0, 0, 0, 0, 0);
  return (Stats){w.s, w.n};
}
