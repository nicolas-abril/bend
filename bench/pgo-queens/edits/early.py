#!/usr/bin/env python3
"""early.py IN.c OUT.c: on opt/integration's queens, a child call that the
call-site arms (#2177) answer no longer stores and pops the frame: the push
moves below the arms, and an answering arm runs the continuation's body
(the sibling call) inline from the parent's locals, then jumps to solve."""
import re, sys
c = open(sys.argv[1]).read()
a = c.index("  WL_CASE(FID_solve)\n")
b = c.index("  WL_CASE(FID_solve_k1)\n")
seg = c[a:b]
push_re = re.compile(r"(            if \(WL_SEQ\(FID_solve\)\) \{\n              WL_ROOM\(9\);\n(?:              STK\(\d\) = [^\n]*\n)+              WL_PUSHN\(9\);\n            \} else \{\n.*?\n            \}\n)", re.S)
pushes = push_re.findall(seg)
assert len(pushes) == 2, len(pushes)
out = seg
for p in pushes:
    stk = dict(re.findall(r"STK\((\d)\) = (\w+);", p))
    g, sib, cols, ld, rd, full, b2, n2 = (stk[str(i)] for i in range(8))
    i = out.index(p)
    j = out.index("            if (!DEVICE && WL_SEQ(FID_solve)) {\n", i)
    k = out.index("            _f_0 = r0;\n", j)
    arms = out[j:k]
    cap = (f"            Term P_g = {g}; u32 P_sib = {sib}, P_cols = {cols}, P_ld = {ld}, P_rd = {rd},"
           f" P_full = {full}, P_b2 = {b2}, P_n2 = {n2};\n")
    inl = ("{ Term h0 = r0, h1 = r1, h2 = r2; r0 = P_g; r1 = U32_BIN(P_sib, ==, 0);"
           " r2 = U32_BIN(P_n2, ==, P_full); r3 = U32_BIN(P_sib, -, P_b2); r4 = P_n2;"
           " r5 = U32_BIN(U32_BIN(P_ld, |, P_b2), <<, 1); r6 = U32_BIN(U32_BIN(P_rd, |, P_b2), >>, 1);"
           " r7 = P_cols; r8 = P_ld; r9 = P_rd; r10 = P_full; r11 = h0; r12 = h1; r13 = h2;"
           " r14 = 0; r15 = 0; WL_JMP(FID_solve); }")
    arms2 = arms.replace("WL_POPN(1); WL_JMP(FID_solve_k1);", inl)
    assert arms2 != arms
    # the push (with its task path) goes after the arms
    out = out[:i] + out[i + len(p):j] + cap + arms2 + p + out[k:]
c = c[:a] + out + c[b:]
open(sys.argv[2], "w").write(c)
