#!/usr/bin/env python3
"""remat_scan.py FILE.c...: frame words that are pure word arithmetic over
other words of the same frame (recomputable in the continuation)."""
import re, sys
PURE = re.compile(r"^[\w\s()+\-*&|^~<>=!,]*$")
for path in sys.argv[1:]:
    c = open(path).read()
    defs = dict(re.findall(r"(?:u32|Term|u64) (_\w+_\d+) = ([^;]*);", c))
    hits = 0
    frames = 0
    for m in re.finditer(r"WL_ROOM\((\d+)\);\n((?:\s*STK\(\d+\) = [^\n]*\n)+)\s*WL_PUSHN", c):
        words = re.findall(r"STK\(\d+\) = (\w+);", m.group(2))
        frames += 1
        ws = set(words)
        def leaves(w, depth=0):
            if w in ws and depth > 0:
                return {w}
            e = defs.get(w)
            if e is None or depth > 6 or not PURE.match(e):
                return None
            for tok in re.findall(r"\b[A-Za-z_]\w*\b", e):
                if not (re.fullmatch(r"_\w+_\d+", tok) or tok in ("U32_BIN", "u64", "u32", "ull")):
                    return None
            out = set()
            for t in re.findall(r"\b_\w+_\d+\b", e):
                l = leaves(t, depth + 1)
                if l is None:
                    return None
                out |= l
            return out
        rec = [w for w in words if w.startswith("_") and (lambda l: l is not None and l <= ws - {w})(leaves(w))]
        if rec:
            hits += 1
            print(f"  {path.split('/')[-4]}: frame {words} recomputable {rec}")
    print(f"{path}: {frames} frame pushes, {hits} with recomputable words")
