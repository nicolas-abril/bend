// L2: L1 in Bend's term encoding: every value a u64 word, U32 ops through
// Bend's U32_BIN (truncate, operate, widen), bools as 0/1 words, the fuel a
// u64 Nat, the result three words (tag, sols, nodes). C recursion still.
#include "common.h"
typedef uint64_t Term;
#define U32_BIN(a, o, b) ((Term)((uint32_t)(a) o (uint32_t)(b)))
typedef struct { Term t, s, n; } R;
static R solve(Term f, Term z, Term e, Term sib, Term nc, Term nl, Term nr, Term cols,
               Term ld, Term rd, Term full, Term rt, Term rs, Term rn, Term sols, Term nodes) {
  for (;;) {
    if (f == 0 || z == 1) {
      if (rt == 0) return (R){1, sols, nodes};
      return (R){1, U32_BIN(sols, +, rs), U32_BIN(nodes, +, rn)};
    }
    Term g = f - 1;
    if (e == 1) {
      Term b2 = U32_BIN(sib, &, U32_BIN(0ull, -, sib)), n2 = U32_BIN(cols, |, b2);
      Term s1 = rt == 0 ? sols : U32_BIN(sols, +, rs), n1 = rt == 0 ? nodes : U32_BIN(nodes, +, rn);
      f = g; z = U32_BIN(sib, ==, 0); e = U32_BIN(n2, ==, full); nc = n2;
      nl = U32_BIN(U32_BIN(ld, |, b2), <<, 1); nr = U32_BIN(U32_BIN(rd, |, b2), >>, 1);
      sib = U32_BIN(sib, -, b2); rt = 0; rs = 0; rn = 0;
      sols = U32_BIN(s1, +, 1); nodes = U32_BIN(n1, +, 1);
      continue;
    }
    Term cc = U32_BIN(full, &, (Term)~(uint32_t)U32_BIN(nc, |, U32_BIN(nl, |, nr)));
    Term cb = U32_BIN(cc, &, U32_BIN(0ull, -, cc)), cn = U32_BIN(nc, |, cb);
    Term b2 = U32_BIN(sib, &, U32_BIN(0ull, -, sib)), n2 = U32_BIN(cols, |, b2);
    Term s1 = rt == 0 ? sols : U32_BIN(sols, +, rs), n1 = rt == 0 ? nodes : U32_BIN(nodes, +, rn);
    R w = solve(g, U32_BIN(cc, ==, 0), U32_BIN(cn, ==, full), U32_BIN(cc, -, cb), cn,
                U32_BIN(U32_BIN(nl, |, cb), <<, 1), U32_BIN(U32_BIN(nr, |, cb), >>, 1),
                nc, nl, nr, full, 0, 0, 0, s1, U32_BIN(n1, +, 1));
    f = g; z = U32_BIN(sib, ==, 0); e = U32_BIN(n2, ==, full); nc = n2;
    nl = U32_BIN(U32_BIN(ld, |, b2), <<, 1); nr = U32_BIN(U32_BIN(rd, |, b2), >>, 1);
    sib = U32_BIN(sib, -, b2); rt = w.t; rs = w.s; rn = w.n; sols = 0; nodes = 0;
  }
}
static Stats root(uint32_t c4, uint32_t l4, uint32_t r4, uint32_t full) {
  uint32_t cc = full & ~(c4 | l4 | r4), cb = cc & (0u - cc), cn = c4 | cb;
  R w = solve((Term)SIZE * SIZE, cc == 0, cn == full, cc - cb, cn, (l4 | cb) << 1,
              (r4 | cb) >> 1, c4, l4, r4, full, 0, 0, 0, 0, 0);
  return (Stats){(uint32_t)w.s, (uint32_t)w.n};
}
