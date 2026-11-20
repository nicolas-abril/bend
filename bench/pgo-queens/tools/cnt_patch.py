#!/usr/bin/env python3
"""cnt_patch.py IN.c OUT.c: counters patched into Bend's emitted C (host).

Counts, per segment (FID), entries (including self-jumps, which re-enter
the function); frames pushed with WL_PUSHN and their words; words popped
(WL_POPN); returns (WL_RETN); tail jumps (WL_JMP, WL_DYN); Nat limit tests
(nat_chk); heap allocs and frees. Printed to stderr at exit.
"""
import re, sys
src = open(sys.argv[1]).read()
hdr = r'''
static unsigned long long cnt_seg[64], cnt_push, cnt_pushw, cnt_pop, cnt_popw, cnt_ret, cnt_jmp, cnt_dyn, cnt_nat, cnt_alloc, cnt_free;
static unsigned long long cnt_pushw_by[32];
#include <stdio.h>
static void cnt_dump(void) __attribute__((destructor));
'''
# after the u64 typedefs
src = src.replace("typedef u64 Term;\n", "typedef u64 Term;\n" + hdr, 1)
rep = [
  ("#define WL_CASE(F) WL_FN WL_##F(WL_SIG) {", "#define WL_CASE(F) WL_FN WL_##F(WL_SIG) { cnt_seg[(F) & 63]++;"),
  ("#define WL_JMP(F)  __attribute__((musttail)) return WL_##F(WL_ALL)",
   "#define WL_JMP(F)  cnt_jmp++; __attribute__((musttail)) return WL_##F(WL_ALL)"),
  ("#define WL_DYN(F)  __attribute__((musttail)) return wl_tab[F](WL_ALL)",
   "#define WL_DYN(F)  cnt_dyn++; __attribute__((musttail)) return wl_tab[F](WL_ALL)"),
  ("#define WL_RETN(N)  { rn = (N);", "#define WL_RETN(N)  { cnt_ret++; rn = (N);"),
  ("#define WL_POPN(N)  sp -= (N) * LANE_STEP", "#define WL_POPN(N)  (cnt_pop++, cnt_popw += (N), sp -= (N) * LANE_STEP)"),
  ("#define WL_PUSHN(N) sp += (N) * LANE_STEP", "#define WL_PUSHN(N) (cnt_push++, cnt_pushw += (N), cnt_pushw_by[(N) & 31]++, sp += (N) * LANE_STEP)"),
]
for a, b in rep:
    if a not in src:
        sys.exit("missing: " + a)
    src = src.replace(a, b, 1)
# FID names for the dump
fids = re.findall(r"^#define (FID_\w+) (\d+)$", src, re.M)
names = "static const char* cnt_names[64] = {" + ",".join('[%s & 63] = "%s"' % (n, n) for n, v in fids if int(v) < 64) + "};\n"
dump = names + r'''
static void cnt_dump(void) {
  fprintf(stderr, "push %llu pushw %llu pop %llu popw %llu ret %llu jmp %llu dyn %llu nat %llu alloc %llu free %llu\n",
    cnt_push, cnt_pushw, cnt_pop, cnt_popw, cnt_ret, cnt_jmp, cnt_dyn, cnt_nat, cnt_alloc, cnt_free);
  for (int i = 0; i < 32; i++) if (cnt_pushw_by[i]) fprintf(stderr, "push_size %d %llu\n", i, cnt_pushw_by[i]);
  for (int i = 0; i < 64; i++) if (cnt_seg[i]) fprintf(stderr, "seg %s %llu\n", cnt_names[i] ? cnt_names[i] : "?", cnt_seg[i]);
}
'''
# nat_chk and heap_alloc / heap_free bodies: count at entry
for fn, c in (("nat_chk", "cnt_nat"), ("heap_alloc", "cnt_alloc"), ("heap_free", "cnt_free")):
    m = re.search(r"^(INLINE|static inline|FAR|static)[^\n]*\b%s\([^)]*\)\s*\{\n" % fn, src, re.M)
    if m:
        src = src[:m.end()] + "  %s++;\n" % c + src[m.end():]
    else:
        print("no", fn, file=sys.stderr)
# the dump after the FID table definition (needs FID_ macros)
i = src.index("// Segments\n")
src = src[:i] + dump + src[i:]
open(sys.argv[2], "w").write(src)
