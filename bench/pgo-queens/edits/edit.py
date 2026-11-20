#!/usr/bin/env python3
"""edit.py IN.c OUT.c EDIT[,EDIT..]: hand edits of queens' emitted solve frame.

The frame solve pushes before its child call is (g, sib, cols, ld, rd, full,
b2, n2, FID). Edits (any combination):
  sat   full stays out of the frame: the continuation reads it from r10, the
        register every solve entry and return carries it in (full is passed
        unchanged by every call of solve, and between the push and the
        continuation only solve runs). Seq path only.
  rec   b2 and n2 stay out of the frame: the continuation recomputes them
        from the frame's sib and cols (b2 = sib & -sib, n2 = cols | b2).
  nofuel  the fuel is dropped (not sound: bounds what the fuel costs).
"""
import re, sys
src, dst, edits = sys.argv[1], sys.argv[2], sys.argv[3].split(",")
c = open(src).read()
a = c.index("  WL_CASE(FID_solve)\n")
b = c.index("  WL_CASE(", c.index("WL_CASE(FID_solve_k", a) + 10)
# the k segments follow solve; find the end of the last k segment
ks = [m.start() for m in re.finditer(r"  WL_CASE\(FID_solve_k\d+\)\n", c)]
end = c.index("  WL_CASE(", ks[-1] + 10)
seg = c[a:end]
keep = ["g", "sib", "cols", "ld", "rd", "full", "b2", "n2"]
drop = set()
if "sat" in edits: drop.add("full")
if "rec" in edits: drop |= {"b2", "n2"}
new = [w for w in keep if w not in drop]
idx = {w: new.index(w) for w in new}
n = len(new)
# pushes: STK(i) = _<w>_<k>; .. STK(8) = FID_solve_kN; WL_PUSHN(9)
def fix_push(m):
    body = m.group(0)
    out = []
    for line in body.split("\n"):
        mm = re.match(r"(\s*)STK\((\d)\) = (.*);$", line)
        if mm:
            i = int(mm.group(2))
            if i == 8:
                out.append(f"{mm.group(1)}STK({n}) = {mm.group(3)};")
            elif keep[i] in drop:
                continue
            else:
                out.append(f"{mm.group(1)}STK({idx[keep[i]]}) = {mm.group(3)};")
        else:
            out.append(line)
    return "\n".join(out).replace("WL_PUSHN(9)", f"WL_PUSHN({n + 1})").replace("WL_ROOM(9)", f"WL_ROOM({n + 1})")
seg = re.sub(r"WL_ROOM\(9\);\n(\s*STK\(\d\) = [^\n]*\n)+\s*WL_PUSHN\(9\);", fix_push, seg)
# continuations: WL_POPN(8); then `T _x_k = STK(i);` lines
def fix_k(m):
    body = m.group(0)
    lines = body.split("\n")
    out = []
    names = {}
    for line in lines:
        mm = re.match(r"(\s*)(Term|u32) (_(\w+?)_\d+) = STK\((\d)\);$", line)
        if mm:
            w = keep[int(mm.group(5))]
            names[w] = mm.group(3)
            if w in drop:
                continue
            out.append(f"{mm.group(1)}{mm.group(2)} {mm.group(3)} = STK({idx[w]});")
        else:
            out.append(line)
    body = "\n".join(out).replace("WL_POPN(8);", f"WL_POPN({n});")
    extra = ""
    if "full" in drop:
        extra += f"    u32 {names['full']} = r10;\n"
    if "b2" in drop:
        extra += (f"    u32 {names['b2']} = U32_BIN({names['sib']}, &, U32_BIN(0ull, -, {names['sib']}));\n"
                  f"    u32 {names['n2']} = U32_BIN({names['cols']}, |, {names['b2']});\n")
    return body.replace("    WL_OPEN\n", extra + "    WL_OPEN\n", 1)
seg = re.sub(r"  WL_CASE\(FID_solve_k\d+\)\n.*?WL_OPEN\n", fix_k, seg, flags=re.S)
if "nofuel" in edits:
    seg = seg.replace("if (_f_0 == 0) {", "if (0) {")
c = c[:a] + seg + c[end:]
open(dst, "w").write(c)
