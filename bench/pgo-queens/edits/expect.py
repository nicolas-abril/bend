#!/usr/bin/env python3
"""expect.py IN.c OUT.c: the arms the compiler knows are rare, hinted: the
sequential test before a frame push (`if (seq)`, `if (WL_SEQ(F))`) is
expected true, the task path of a continuation (`!seq && fid_nofk(..)`,
`!WL_SEQ(..) && fid_nofk(..)`) expected false."""
import re, sys
c = open(sys.argv[1]).read()
n = 0
for a, b in ((r"if \(seq\) \{", "if (__builtin_expect(seq, 1)) {"),
             (r"if \(WL_SEQ\((\w+)\)\) \{", r"if (__builtin_expect(WL_SEQ(\1), 1)) {"),
             (r"if \((!DEVICE && !(?:seq|WL_SEQ\(\w+\)) && fid_nofk\(\w+\))\) \{", r"if (__builtin_expect(\1, 0)) {")):
    c, k = re.subn(a, b, c)
    n += k
open(sys.argv[2], "w").write(c)
print(n, "hints", file=sys.stderr)
