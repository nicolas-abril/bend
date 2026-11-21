#!/usr/bin/env python3
"""asmcount.py X.s [FN..]: instructions per function in clang's arm64 asm
(lines between a function label and its .cfi_endproc that are instructions),
and loads / stores among them."""
import re, sys
s = open(sys.argv[1]).read().split("\n")
want = sys.argv[2:]
cur, out = None, {}
for l in s:
    m = re.match(r"^(_\w+):", l)
    if m and not m.group(1).startswith("_.") and not l.startswith("Ltmp"):
        cur = m.group(1)[1:]
        out.setdefault(cur, [0, 0, 0, 0])
        continue
    if l.strip().startswith(".cfi_endproc"):
        cur = None
        continue
    if cur and re.match(r"^\s+[a-z]", l) and not l.strip().startswith("."):
        op = l.split()[0]
        o = out[cur]
        o[0] += 1
        o[1] += op.startswith("ld")
        o[2] += op.startswith("st")
        o[3] += op in ("b", "br", "cbz", "cbnz", "tbz", "tbnz", "ret") or op.startswith("b.")
for f, (n, ld, st, br) in out.items():
    if not want or any(w == f or f.startswith(w) for w in want):
        print(f"{f}\t{n}\tld {ld}\tst {st}\tbr {br}")
