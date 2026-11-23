#!/usr/bin/env python3
"""cdiff.py A_DIR B_DIR [LIST]: names whose C differs once B's runtime additions
(the DST_PUT / WL_DEST macros and the #ifdef FID_Dst_put case) are removed"""
import os, re, sys
a, b = sys.argv[1:3]
def norm(t):
    t = re.sub(r"// A hole is a field's word.*?\n// pushes one \[R, hole, FID\]\) and makes R's field J the hole\.\n", "", t, flags=re.S)
    t = re.sub(r"#define DST_PUT\(H, X\) do \{.*?\} while \(0\)\n", "", t, flags=re.S)
    t = re.sub(r"#define WL_DEST\(R, J, S\) do \{.*?\} while \(0\)\n", "", t, flags=re.S)
    t = re.sub(r"#ifdef FID_Dst_put\n.*?#endif\n", "", t, flags=re.S)
    return t
names = [l.split()[0] for l in open(sys.argv[3])] if len(sys.argv) > 3 else sorted(f[:-2] for f in os.listdir(b) if f.endswith(".c"))
for n in names:
    fa, fb = f"{a}/{n}.c", f"{b}/{n}.c"
    if os.path.exists(fa) and os.path.exists(fb) and open(fa).read() != norm(open(fb).read()):
        print(n)
