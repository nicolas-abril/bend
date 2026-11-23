#!/usr/bin/env python3
# emit244.py ROOT TAG: (30 emits per call of tools/heavy.sh, one at a time, 4096 MB) bend-benchmarks' 244 programs to W/c/TAG/<name>.c (cwd = the program's dir)
import os, subprocess, sys
HV = "/Users/macolas/Software/bend-benchmarks/tools/heavy.sh"
BB = "/Users/macolas/Software/bend-benchmarks"; W = "/private/tmp/bend-opt/par/b244"
def programs():
    out = []
    for d, _, fs in os.walk(BB):
        if "/.git" in d or "/reference" in d or "/tools" in d: continue
        out += [os.path.join(d, f) for f in fs if f.endswith(".bend")]
    return sorted(out)
name = lambda p: os.path.relpath(p, BB).replace("/", "__")[:-5]
root, tag = sys.argv[1], sys.argv[2]
j = 1  # one heavy process at a time (memory rules)
os.makedirs(f"{W}/c/{tag}", exist_ok=True)
def emit_batch(grp):
    lines = []
    for p in grp:
        dst = f"{W}/c/{tag}/{name(p)}.c"
        lines.append(f"cd {os.path.dirname(p)}; BUN_JSC_forceRAMSize=3000000000 bun {root}/bend2/main.ts {p} -o {dst}.tmp.c > {dst[:-2]}.emitlog 2>&1 && mv {dst}.tmp.c {dst} || echo EMITFAIL {name(p)}")
    r = subprocess.run([HV, str(900 * len(grp)), "4096", "--", "bash", "-c", "\n".join(lines)], capture_output=True, text=True)
    print(r.stdout + r.stderr[-500:], end="", flush=True)

ps = [p for p in programs() if not os.path.exists(f"{W}/c/{tag}/{name(p)}.c")]
print(len(ps), "to emit")
for i in range(0, len(ps), 30):
    emit_batch(ps[i:i + 30])
print("done", tag)
