#!/usr/bin/env python3
"""memchk.py C [C..]: build each with live-word counting and -DBEND_POISON, run at 1 and 8 threads"""
import sys, subprocess, importlib.util, os
spec = importlib.util.spec_from_file_location("lane", "/private/tmp/bend-opt/gen/tools/lane.py")
lane = importlib.util.module_from_spec(spec); spec.loader.exec_module(lane)
L = os.path.expanduser("~/Software/supgen-bend/limit")
for c in sys.argv[1:]:
    src = lane.mem_patch(open(c).read())
    b = os.path.abspath(c[:-2] + ".mem")
    open(b + ".c", "w").write(src)
    subprocess.run([L, "600", "6144", "cc", "-std=c11", "-O3", "-w", "-DBEND_POISON", b + ".c", "-o", b, "-lpthread", "-lm"], check=True)
    for t in (1, 8):
        p = subprocess.run([L, "120", "6144", b, "+RTS", "--threads", str(t), "--gpu", "off", "-RTS"], capture_output=True, text=True)
        live = [l for l in p.stderr.split("\n") if l.startswith("LIVE")]
        print(os.path.basename(c), f"t{t}", "rc", p.returncode, live[-1] if live else "nolive", p.stdout.strip()[-80:])
