// L0: the suite twin's solve (C recursion, sibling loop), shared driver.
#include "common.h"
static Stats solve(uint32_t cand, uint32_t cols, uint32_t ld, uint32_t rd,
                   uint32_t full, uint32_t sols, uint32_t nodes) {
  while (cand != 0u) {
    uint32_t bit = cand & (0u - cand), nc = cols | bit;
    if (nc == full) { sols += 1u; nodes += 1u; }
    else {
      uint32_t nl = (ld | bit) << 1, nr = (rd | bit) >> 1;
      Stats w = solve(full & ~(nc | nl | nr), nc, nl, nr, full, sols, nodes + 1u);
      sols = w.sols; nodes = w.nodes;
    }
    cand -= bit;
  }
  return (Stats){sols, nodes};
}
static Stats root(uint32_t c4, uint32_t l4, uint32_t r4, uint32_t full) {
  return solve(full & ~(c4 | l4 | r4), c4, l4, r4, full, 0u, 0u);
}
