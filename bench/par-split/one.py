#!/usr/bin/env python3 -I
# one.py EXE THREADS: run under tm once, print one JSON line (others' CPU before/after)
import json, os, re, subprocess, sys
TM = "/private/tmp/bend-opt/par/tm"
def others():
    me = os.getpgrp()
    out = subprocess.run(["ps", "-A", "-o", "pgid=,pcpu="], capture_output=True, text=True).stdout
    return sum(float(c) for g, c in (l.split() for l in out.splitlines()) if int(g) != me) / 100
exe, th = sys.argv[1], sys.argv[2]
o0 = others()
p = subprocess.run([TM, exe] + sys.argv[3:] + ["+RTS", "--threads", th, "--gpu", "off", "-RTS"], capture_output=True, text=True)
line = ([l for l in p.stderr.splitlines() if l.startswith("rc=")] or [""])[-1]
rec = {k: (float(v) if re.match(r"^-?[\d.]+$", v) else v) for k, v in (kv.split("=") for kv in line.split())}
rec.update(others=o0, others_after=others(), load=os.getloadavg()[0], out=p.stdout)
print(json.dumps(rec))
