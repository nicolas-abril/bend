#!/usr/bin/env python3
"""wrong.py NAME DST: a copy of the branch's bend2/ with one deliberate bug."""
import shutil, sys
W = {
  "nofixed": ("|| FL.fixed.has(c?.f) ", ""),
  "noreadmask": ('return b > 32 ? w : `(u32)(${w} >> ${s})${b < 32 ? ` & ${2 ** b - 1}u` : ""}`;', 'return b > 32 ? w : `(u32)(${w} >> ${s})`;'),
  "overlap": ("used[i] += b;", "used[i] += Math.max(b - 1, 1);"),
  "arity": ("n = pk?.n ?? lay.ks.length;", "n = lay.ks.length;"),
  "spine": ("n - 1 - (pk?.at[at][0] ?? at)", "n - 1 - at"),
  "bits64": ("u + b <= 56", "u + b <= 64"),
  "nowritemask": ('${b < 32 ? ` & ${2 ** b - 1}u` : ""}) << ${s}', ') << ${s}'),
  "sparecls": ("const spare = { cls: cls_fit(n),", "const spare = { cls: cls_fit(node.ks.length),"),
}
name, dst = sys.argv[1:3]
shutil.rmtree(dst, ignore_errors=True)
shutil.copytree("/private/tmp/bend-opt/rep/bend2", dst)
s = open(f"{dst}/comp.ts").read()
a, b = W[name]
assert s.count(a) == 1, (name, s.count(a))
open(f"{dst}/comp.ts", "w").write(s.replace(a, b))
