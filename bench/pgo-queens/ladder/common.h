// Shared driver of the queens ladder: the suite twin's prefix decode and
// batch loop; each rung defines root(c4, l4, r4, full) for one prefix.
#include <stdint.h>
#include <stdio.h>
#define DEPTH 17u
#ifndef SIZE
#define SIZE 17u
#endif
#define LIMIT 11730u
typedef struct { uint32_t sols, nodes; } Stats;
static Stats root(uint32_t c4, uint32_t l4, uint32_t r4, uint32_t full);
static Stats pfx(uint32_t j, uint32_t nn, uint32_t full, uint32_t bound) {
  uint32_t i = (j * 2654435761u) & ((1u << DEPTH) - 1u);
  if (!(i < bound)) return (Stats){0u, 0u};
  uint32_t nn2 = nn * nn;
  uint32_t b0 = 1u << (i / (nn2 * nn));
  uint32_t b1 = 1u << ((i / nn2) % nn);
  if ((b1 & (b0 | (b0 << 1) | (b0 >> 1))) != 0u) return (Stats){0u, 0u};
  uint32_t b2 = 1u << ((i / nn) % nn);
  uint32_t c2 = b0 | b1, l2 = ((b0 << 1) | b1) << 1, r2 = ((b0 >> 1) | b1) >> 1;
  if ((b2 & (c2 | l2 | r2)) != 0u) return (Stats){0u, 0u};
  uint32_t b3 = 1u << (i % nn);
  uint32_t c3 = c2 | b2, l3 = (l2 | b2) << 1, r3 = (r2 | b2) >> 1;
  if ((b3 & (c3 | l3 | r3)) != 0u) return (Stats){0u, 0u};
  uint32_t c4 = c3 | b3, l4 = (l3 | b3) << 1, r4 = (r3 | b3) >> 1;
  return root(c4, l4, r4, full);
}
int main(void) {
  uint32_t nn = SIZE, full = (1u << nn) - 1u, nnnn = nn * nn * nn * nn;
  uint32_t bound = LIMIT < nnnn ? LIMIT : nnnn, sols = 0u, nodes = 0u;
  for (uint32_t i = 0u; i < (1u << DEPTH); ++i) {
    Stats s = pfx(i, nn, full, bound);
    sols += s.sols; nodes += s.nodes;
  }
  printf("%u\n", (sols * 2654435761u) ^ nodes);
  return 0;
}
