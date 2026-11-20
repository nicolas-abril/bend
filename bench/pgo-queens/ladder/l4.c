// L4: L3 as Bend's host segments: solve, its continuation k1 and an exit,
// each a preserve_none function taking Bend's register bank (Env, sp, seq,
// rn, r0..r5, rp, r6..r15); jumps are musttail calls, the self call too;
// a return pops the id and jumps through a table. -DTWO_K: the descend
// arm's two spellings (ret Stat0 / Stats) push two equal continuations,
// as main does (#2153 merges them).
#include "common.h"
#include <stdlib.h>
typedef uint64_t Term;
typedef uint32_t u32;
typedef struct { Term* mem; Term* alc; } Env;
#define U32_BIN(a, o, b) ((Term)((uint32_t)(a) o (uint32_t)(b)))
#define PN __attribute__((preserve_none))
#define SIG Env e, Term* sp, u32 seq, u32 rn, Term r0, Term r1, Term r2, Term r3, Term r4, Term r5, Term rp, Term r6, Term r7, Term r8, Term r9, Term r10, Term r11, Term r12, Term r13, Term r14, Term r15
#define ALL e, sp, seq, rn, r0, r1, r2, r3, r4, r5, rp, r6, r7, r8, r9, r10, r11, r12, r13, r14, r15
typedef Term (PN *Fn)(SIG);
enum { F_SOLVE, F_K1, F_K3, F_EXIT };
static __attribute__((noinline)) PN Term s_solve(SIG);
static __attribute__((noinline)) PN Term s_k1(SIG);
static __attribute__((noinline)) PN Term s_k3(SIG);
static __attribute__((noinline)) PN Term s_exit(SIG);
static const Fn tab[] = {s_solve, s_k1, s_k3, s_exit};
#define JMP(F) __attribute__((musttail)) return F(ALL)
#define RETN(N) { rn = (N); sp -= 1; __attribute__((musttail)) return tab[(u32)sp[0]](ALL); }
static Term out1, out2;
#ifdef TWO_K
#define KB F_K3
#else
#define KB F_K1
#endif
static PN Term s_solve(SIG) {
  Term _f = r0; Term z = r1, ee = r2, sib = r3, nc = r4, nl = r5, nr = r6, cols = r7, ld = r8,
       rd = r9, full = r10, rt = r11, rs = r12, rnn = r13, sols = r14, nodes = r15;
  if (_f == 0 || z == 1) {
    r0 = 1;
    if (rt == 0) { r1 = sols; r2 = nodes; } else { r1 = U32_BIN(sols, +, rs); r2 = U32_BIN(nodes, +, rnn); }
    RETN(3);
  }
  Term g = _f - 1;
  if (ee == 1) {
    Term b2 = U32_BIN(sib, &, U32_BIN(0ull, -, sib)), n2 = U32_BIN(cols, |, b2);
    Term s1 = rt == 0 ? sols : U32_BIN(sols, +, rs), n1 = rt == 0 ? nodes : U32_BIN(nodes, +, rnn);
    r0 = g; r1 = U32_BIN(sib, ==, 0); r2 = U32_BIN(n2, ==, full); r3 = U32_BIN(sib, -, b2); r4 = n2;
    r5 = U32_BIN(U32_BIN(ld, |, b2), <<, 1); r6 = U32_BIN(U32_BIN(rd, |, b2), >>, 1);
    r7 = cols; r8 = ld; r9 = rd; r10 = full; r11 = 0; r12 = 0; r13 = 0;
    r14 = U32_BIN(s1, +, 1); r15 = U32_BIN(n1, +, 1);
    JMP(s_solve);
  }
  Term cc = U32_BIN(full, &, (Term)~(uint32_t)U32_BIN(nc, |, U32_BIN(nl, |, nr)));
  Term cb = U32_BIN(cc, &, U32_BIN(0ull, -, cc)), cn = U32_BIN(nc, |, cb);
  Term b2 = U32_BIN(sib, &, U32_BIN(0ull, -, sib)), n2 = U32_BIN(cols, |, b2);
  Term a13 = U32_BIN(nl, |, cb), a14 = U32_BIN(nr, |, cb);
  sp[0] = g; sp[1] = sib; sp[2] = cols; sp[3] = ld; sp[4] = rd; sp[5] = full; sp[6] = b2; sp[7] = n2;
  if (rt == 0) {
    sp[8] = F_K1; sp += 9;
    r14 = sols; r15 = U32_BIN(nodes, +, 1);
  } else {
    sp[8] = KB; sp += 9;
    r14 = U32_BIN(sols, +, rs); r15 = U32_BIN(U32_BIN(nodes, +, rnn), +, 1);
  }
  r0 = g; r1 = U32_BIN(cc, ==, 0); r2 = U32_BIN(cn, ==, full); r3 = U32_BIN(cc, -, cb); r4 = cn;
  r5 = U32_BIN(a13, <<, 1); r6 = U32_BIN(a14, >>, 1); r7 = nc; r8 = nl; r9 = nr; r10 = full;
  r11 = 0; r12 = 0; r13 = 0;
  JMP(s_solve);
}
#define KBODY \
  sp -= 8; \
  Term g = sp[0], sb = sp[1], cl = sp[2], l = sp[3], r = sp[4], fu = sp[5], b2 = sp[6], n2 = sp[7]; \
  Term h0 = r0, h1 = r1, h2 = r2; \
  r0 = g; r1 = U32_BIN(sb, ==, 0); r2 = U32_BIN(n2, ==, fu); r3 = U32_BIN(sb, -, b2); r4 = n2; \
  r5 = U32_BIN(U32_BIN(l, |, b2), <<, 1); r6 = U32_BIN(U32_BIN(r, |, b2), >>, 1); \
  r7 = cl; r8 = l; r9 = r; r10 = fu; r11 = h0; r12 = h1; r13 = h2; r14 = 0; r15 = 0; \
  JMP(s_solve);
static PN Term s_k1(SIG) { KBODY }
static PN Term s_k3(SIG) { KBODY }
static PN Term s_exit(SIG) { out1 = r1; out2 = r2; return 0; }
static Term* stack_base;
static Stats root(uint32_t c4, uint32_t l4, uint32_t r4, uint32_t full) {
  if (!stack_base) stack_base = malloc(sizeof(Term) << 20);
  Term* sp = stack_base;
  *sp++ = F_EXIT;
  uint32_t cc = full & ~(c4 | l4 | r4), cb = cc & (0u - cc), cn = c4 | cb;
  Env e = {stack_base, stack_base};
  s_solve(e, sp, 1, 0, (Term)SIZE * SIZE, cc == 0, cn == full, cc - cb, cn, (l4 | cb) << 1, 0,
          (r4 | cb) >> 1, c4, l4, r4, full, 0, 0, 0, 0, 0);
  return (Stats){(uint32_t)out1, (uint32_t)out2};
}
