#!/usr/bin/env python3
"""edits.py VARIANT IN.c OUT.c: hand edits of queens' emitted C that bound
the two steps of the accumulator rewrite (bench/acc-rewrite/README.md).

  s2a  (from the port's C)  step 2 without dropping the parameter: each
       continuation of solve's child call adds the child's (sols, nodes)
       into the sibling's running totals where it arrives and passes
       ret = Stat0 (tag 0, fields 0). The match on ret stays; at run time
       only the Stat0 arms run.
  s2b  (from r1's C)        step 2 with the dead ret dropped (13 words in,
       as r1) but the Stats tag kept on the return: solve returns
       (1, sols, nodes) in three words and its continuations read words 1
       and 2.
  s12a (from s1's C)        both steps, ret kept as a parameter that is
       always (0, 0): the continuation passes ret = (0, 0) and the child's
       pair into (sols, nodes).
  s12b (from s1's C)        both steps with the constant ret dropped:
       solve takes 13 words, r1's shape, compiled from the port's rows.
  m1k  (from the port's C on main)  the Stats arms push k1 instead of k3
       (their code is equal): one return target, as #2153 makes it on
       opt/integration; nothing else changes. Isolates the second return
       target from the tag test.
"""
import re, sys


def seg(src, fid):
    """(start, end) of the WL_CASE(fid) segment: up to the next WL_CASE or #if."""
    a = src.index(f"  WL_CASE({fid})\n")
    m = re.compile(r"\n(  WL_CASE\(|#if !DEVICE\n  WL_CASE)").search(src, a + 10)
    return a, m.start() + 1


def sub_in(src, fid, fn):
    a, b = seg(src, fid)
    return src[:a] + fn(src[a:b]) + src[b:]


def must(pat, repl, s, count=0, flags=0):
    n = len(re.findall(pat, s, flags))
    if n == 0:
        raise SystemExit(f"no match: {pat}")
    return re.sub(pat, repl, s, count=count, flags=flags)


def fid_num(src, fid):
    return int(re.search(r"#define %s (\d+)\n" % fid, src).group(1))


def m1k(src):
    def solve(s):
        s = must(r"STK\(8\) = FID_solve_k3;", "STK(8) = FID_solve_k1;", s)
        s = must(r"task_node\(e, FID_solve_k3,", "task_node(e, FID_solve_k1,", s)
        return must(r"term_tsk\(FID_solve_k3,", "term_tsk(FID_solve_k1,", s)
    return sub_in(src, "FID_solve", solve)


def s2a(src):
    def k(s):
        # r11..r15 = h0 h1 h2 0 0  ->  0 0 0 h1 h2 (and the task-node copy)
        s = must(r"r11 = (_h_\d+);\n(\s*)r12 = (_h_\d+);\n\s*r13 = (_h_\d+);\n\s*r14 = 0ull;\n\s*r15 = 0ull;",
                 r"r11 = 0;\n\2r12 = 0;\n\2r13 = 0;\n\2r14 = \3;\n\2r15 = \4;", s)
        s = must(r"(?P<p>e\.mem\[_t_\d+ \+ )11\] = (_h_\d+);\n(\s*)(?P=p)12\] = (_h_\d+);\n\s*(?P=p)13\] = (_h_\d+);\n\s*(?P=p)14\] = 0ull;\n\s*(?P=p)15\] = 0ull;",
                 r"\g<p>11] = 0;\n\3\g<p>12] = 0;\n\3\g<p>13] = 0;\n\3\g<p>14] = \4;\n\3\g<p>15] = \5;", s)
        return s
    for fid in ("FID_solve_k1", "FID_solve_k3"):
        if f"WL_CASE({fid})" in src:
            src = sub_in(src, fid, k)
    return src


def s2b(src):
    def solve(s):
        s = must(r"r0 = (_acc_0);\n(\s*)r1 = (_acc_1);\n(\s*)(WL_RETN\(2\)|WL_POPN\(1\); WL_JMP\(FID_solve_k1\))",
                 lambda m: f"r0 = 1;\n{m.group(2)}r1 = {m.group(1)};\n{m.group(2)}r2 = {m.group(3)};\n{m.group(4)}"
                 + m.group(5).replace("WL_RETN(2)", "WL_RETN(3)"), s)
        return s
    src = sub_in(src, "FID_solve", solve)
    src = sub_in(src, "FID_solve_k1", lambda s: must(r"u32 _h_0 = r0;\n(\s*)u32 _h_1 = r1;", r"u32 _h_0 = r1;\n\1u32 _h_1 = r2;", s))
    src = sub_in(src, "FID_batch_k1", lambda s: must(r"u32 _h_0 = r0;\n(\s*)u32 _h_1 = r1;", r"u32 _h_0 = r1;\n\1u32 _h_1 = r2;", s))
    # FID_T: solve_k1 is FID 1, batch_k1 FID 4: arity and result words +1
    def fidt(m):
        ents = re.findall(r"\{ \d+, \d+, \d+, \d+ \}", m.group(0))
        for i in (fid_num(src, "FID_solve_k1"), fid_num(src, "FID_batch_k1")):
            a, r, b, n = map(int, re.findall(r"\d+", ents[i]))
            assert r == 2, ents[i]
            ents[i] = "{ %d, %d, %d, %d }" % (a + 1, r + 1, b, n)
        return "CONSTV Fid FID_T[] = { " + ", ".join(ents) + " };"
    return must(r"CONSTV Fid FID_T\[\] = \{.*\};", fidt, src, count=1)


def s12a(src):
    def k(s):
        s = must(r"r11 = (_h_\d+);\n(\s*)r12 = (_h_\d+);\n\s*r13 = 0ull;\n\s*r14 = 0ull;",
                 r"r11 = 0;\n\2r12 = 0;\n\2r13 = \1;\n\2r14 = \3;", s)
        s = must(r"(?P<p>e\.mem\[_t_\d+ \+ )11\] = (_h_\d+);\n(\s*)(?P=p)12\] = (_h_\d+);\n\s*(?P=p)13\] = 0ull;\n\s*(?P=p)14\] = 0ull;",
                 r"\g<p>11] = 0;\n\3\g<p>12] = 0;\n\3\g<p>13] = \2;\n\3\g<p>14] = \4;", s)
        return s
    return sub_in(src, "FID_solve_k1", k)


def s12b(src):
    src = s12a(src)

    def drop(s):
        # ret (r11, r12) is (0, 0) at every call: drop it, fold its uses
        s = re.sub(r"\n\s*u32 _ret_[01] = r1[12];", "", s)
        s = re.sub(r"\n\s*_ret_[01] = r1[12];", "", s)
        s = re.sub(r"\n\s*r1[12] = 0(ull)?;", "", s)
        s = re.sub(r"\n\s*(e\.mem\[_t_\d+ \+ )1[12]\] = 0(ull)?;", "", s)
        s = re.sub(r"U32_BIN\(([^,()]+), \+, _ret_[01]\)", r"\1", s)
        assert "_ret_" not in s, s[s.index("_ret_") - 200:s.index("_ret_") + 100]
        s = re.sub(r"\br13\b", "r11", s)
        s = re.sub(r"\br14\b", "r12", s)
        s = re.sub(r"(e\.mem\[_t_\d+ \+ )13\]", r"\g<1>11]", s)
        s = re.sub(r"(e\.mem\[_t_\d+ \+ )14\]", r"\g<1>12]", s)
        return s
    for fid in ("FID_solve", "FID_solve_k1"):
        src = sub_in(src, fid, drop)
    # the first call, in batch (pfx.s3 inlined): ret = (0, 0) dropped
    def first(s):
        i = s.index("WL_JMP(FID_solve)")
        j = s.rindex("e.mem[_t_", 0, i)
        k0 = s.rindex("task_node(e, FID_solve,", 0, i)
        blk = s[k0 - 200:i + 20]
        nb = re.sub(r"\n\s*r1[12] = 0(ull)?;", "", blk)
        nb = re.sub(r"\n\s*(e\.mem\[_t_\d+ \+ )1[12]\] = 0(ull)?;", "", nb)
        nb = re.sub(r"\br13\b", "r11", nb)
        nb = re.sub(r"\br14\b", "r12", nb)
        nb = re.sub(r"(e\.mem\[_t_\d+ \+ )13\]", r"\g<1>11]", nb)
        nb = re.sub(r"(e\.mem\[_t_\d+ \+ )14\]", r"\g<1>12]", nb)
        return s[:k0 - 200] + nb + s[i + 20:]
    src = sub_in(src, "FID_batch", first)
    src = must(r"CONSTV Fid FID_T\[\] = \{ \{ 15,", "CONSTV Fid FID_T[] = { { 13,", src, count=1)
    return src


if __name__ == "__main__":
    v, i, o = sys.argv[1:4]
    open(o, "w").write(globals()[v](open(i).read()))
