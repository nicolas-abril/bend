// L3: L2 with an explicit frame stack in one loop: the child call pushes
// Bend's 9-word frame (g, sib, cols, ld, rd, full, b2, n2, id) on a heap
// stack and jumps to the entry; a return pops the id and dispatches by
// compare (k1 or exit); k1 pops the frame and runs the sibling call.
#include "common.h"
#include <stdlib.h>
typedef uint64_t Term;
#define U32_BIN(a, o, b) ((Term)((uint32_t)(a) o (uint32_t)(b)))
enum { K1 = 1, EXIT = 2 };
static Term* stack_base;
static Stats root(uint32_t c4, uint32_t l4, uint32_t r4, uint32_t full0) {
  if (!stack_base) stack_base = malloc(sizeof(Term) << 20);
  Term* sp = stack_base;
  *sp++ = EXIT;
  uint32_t cc0 = full0 & ~(c4 | l4 | r4), cb0 = cc0 & (0u - cc0), cn0 = c4 | cb0;
  Term f = (Term)SIZE * SIZE, z = cc0 == 0, e = cn0 == full0, sib = cc0 - cb0, nc = cn0,
       nl = (l4 | cb0) << 1, nr = (r4 | cb0) >> 1, cols = c4, ld = l4, rd = r4, full = full0,
       rt = 0, rs = 0, rn = 0, sols = 0, nodes = 0;
  Term r0, r1, r2;
entry:
  if (f == 0 || z == 1) {
    r0 = 1;
    if (rt == 0) { r1 = sols; r2 = nodes; }
    else { r1 = U32_BIN(sols, +, rs); r2 = U32_BIN(nodes, +, rn); }
    goto ret;
  } else {
    Term g = f - 1;
    if (e == 1) {
      Term b2 = U32_BIN(sib, &, U32_BIN(0ull, -, sib)), n2 = U32_BIN(cols, |, b2);
      Term s1 = rt == 0 ? sols : U32_BIN(sols, +, rs), n1 = rt == 0 ? nodes : U32_BIN(nodes, +, rn);
      f = g; z = U32_BIN(sib, ==, 0); e = U32_BIN(n2, ==, full); nc = n2;
      nl = U32_BIN(U32_BIN(ld, |, b2), <<, 1); nr = U32_BIN(U32_BIN(rd, |, b2), >>, 1);
      sib = U32_BIN(sib, -, b2); rt = 0; rs = 0; rn = 0;
      sols = U32_BIN(s1, +, 1); nodes = U32_BIN(n1, +, 1);
      goto entry;
    }
    Term cc = U32_BIN(full, &, (Term)~(uint32_t)U32_BIN(nc, |, U32_BIN(nl, |, nr)));
    Term cb = U32_BIN(cc, &, U32_BIN(0ull, -, cc)), cn = U32_BIN(nc, |, cb);
    Term b2 = U32_BIN(sib, &, U32_BIN(0ull, -, sib)), n2 = U32_BIN(cols, |, b2);
    Term s1 = rt == 0 ? sols : U32_BIN(sols, +, rs), n1 = rt == 0 ? nodes : U32_BIN(nodes, +, rn);
    sp[0] = g; sp[1] = sib; sp[2] = cols; sp[3] = ld; sp[4] = rd; sp[5] = full;
    sp[6] = b2; sp[7] = n2; sp[8] = K1; sp += 9;
    Term a13 = U32_BIN(nl, |, cb), a14 = U32_BIN(nr, |, cb);
    f = g; z = U32_BIN(cc, ==, 0); e = U32_BIN(cn, ==, full); sib = U32_BIN(cc, -, cb);
    cols = nc; ld = nl; rd = nr; nc = cn; nl = U32_BIN(a13, <<, 1); nr = U32_BIN(a14, >>, 1);
    rt = 0; rs = 0; rn = 0; sols = s1; nodes = U32_BIN(n1, +, 1);
    goto entry;
  }
ret:
  sp -= 1;
  if (sp[0] == K1) {
    sp -= 8;
    Term g = sp[0], sb = sp[1], cl = sp[2], l = sp[3], r = sp[4], fu = sp[5], b2 = sp[6], n2 = sp[7];
    f = g; z = U32_BIN(sb, ==, 0); e = U32_BIN(n2, ==, fu); sib = U32_BIN(sb, -, b2); nc = n2;
    nl = U32_BIN(U32_BIN(l, |, b2), <<, 1); nr = U32_BIN(U32_BIN(r, |, b2), >>, 1);
    cols = cl; ld = l; rd = r; full = fu; rt = r0; rs = r1; rn = r2; sols = 0; nodes = 0;
    goto entry;
  }
  return (Stats){(uint32_t)r1, (uint32_t)r2};
}
