#!/usr/bin/env python3
"""fdiff.py A.s B.s [PROFDATA]: functions present in one assembly and not
the other (inlining moved), and the size change of shared ones, sorted by
profile count when a profile is given."""
import re, subprocess, sys
def funcs(p):
    out, cur, n = {}, None, 0
    for l in open(p):
        m = re.search(r"-- Begin function (\S+)", l)
        if m:
            cur = m.group(1); out[cur] = 0; continue
        if cur and re.match(r"^\s+[a-z]", l) and not l.strip().startswith("."):
            out[cur] += 1
        if "-- End function" in l:
            cur = None
    return out
a, b = funcs(sys.argv[1]), funcs(sys.argv[2])
cnt = {}
if len(sys.argv) > 3:
    top = subprocess.run(["xcrun", "llvm-profdata", "show", "--topn=400", sys.argv[3]], capture_output=True, text=True).stdout
    cnt = {f.split(":")[-1]: int(c) for f, c in re.findall(r"^\s+(\S+), max count = (\d+)", top, re.M)}
key = lambda f: -cnt.get(f, 0)
print("only in", sys.argv[1], ":", ", ".join(f"{f}({cnt.get(f,0):.2g})" for f in sorted(set(a) - set(b), key=key)[:25]))
print("only in", sys.argv[2], ":", ", ".join(f"{f}({cnt.get(f,0):.2g})" for f in sorted(set(b) - set(a), key=key)[:25]))
print("shared, by count (instructions A -> B):")
for f in sorted(set(a) & set(b), key=key)[:20]:
    print(f"  {f:40} {cnt.get(f,0):12.3g} {a[f]:6} -> {b[f]:6}")
