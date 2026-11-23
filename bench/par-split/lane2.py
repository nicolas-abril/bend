#!/usr/bin/env python3
"""lane2.py: the native lane and the memory check, in batches, each one call of bend-benchmarks'
tools/heavy.sh (the machine-wide lock, free memory first, a 4096 MB cap; bun with BUN_JSC_forceRAMSize).

  lane2.py list OUT ROOT                 tests with expected lines (as lane.py list)
  lane2.py emit ROOT TAG LIST            C into W/c/TAG/<name>.c (30 emits per hold)
  lane2.py derive FROM TAG LIST SED      W/c/TAG/<name>.c = W/c/FROM/<name>.c with a python re.sub (SED = 'pat=>rep')
  lane2.py run TAG LIST [--mem] [--only FILE]   build -O3 (--mem: live words, -DBEND_POISON, threads 1 and 8), run
                                         (20 per hold); results W/c/TAG.<list>.<run|mem>.json
  lane2.py cmp A B LIST ROOT [--mem]     statuses
"""
import json, os, re, subprocess, sys
W = "/private/tmp/bend-opt/par/lane"
H = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, H)
L = "~/Software/supgen-bend/limit"
LOCK = "/private/tmp/bend-opt/timing.lock"
src = open(f"{H}/lane.py").read().split("if __name__")[0]
exec(src.replace('W = "/private/tmp/bend-opt/par/lane"', f'W = "{W}"'))

def hold(script, secs):
    return subprocess.run(["/Users/macolas/Software/bend-benchmarks/tools/heavy.sh", str(secs), "4096", "--", "bash", "-c", script], capture_output=True, text=True, errors="replace", timeout=secs + 1900)

def emit(root, tag, lst):
    os.makedirs(f"{W}/c/{tag}", exist_ok=True)
    items = [x for x in read_list(lst) if not os.path.exists(f"{W}/c/{tag}/{x[0]}.c")]
    for i in range(0, len(items), 30):
        sh_ = "\n".join(f"cd {root}; BUN_JSC_forceRAMSize=3000000000 bun {root}/bend2/main.ts {p} -o {W}/c/{tag}/{n}.tmp.c > /dev/null 2>&1 && mv {W}/c/{tag}/{n}.tmp.c {W}/c/{tag}/{n}.c || echo EMITFAIL {n}" for n, p in items[i:i + 30])
        print(hold(sh_, 30 * 700).stdout, end="", flush=True)
    print("emitted", tag)

def derive(frm, tag, lst, sed):
    pat, rep = sed.split("=>")
    os.makedirs(f"{W}/c/{tag}", exist_ok=True)
    n = 0
    for name, _ in read_list(lst):
        f = f"{W}/c/{frm}/{name}.c"
        if os.path.exists(f):
            c, k = re.subn(pat, rep, open(f).read())
            n += k > 0
            open(f"{W}/c/{tag}/{name}.c", "w").write(c)
    print("derived", n, "changed")

def run(tag, lst, mem, only):
    keep = set(open(only).read().split()) if only else None
    res_f = f"{W}/c/{tag}.{os.path.basename(lst)}.{'mem' if mem else 'run'}.json"
    res = json.load(open(res_f)) if os.path.exists(res_f) else {}
    items = [x for x in read_list(lst) if (keep is None or x[0] in keep) and x[0] not in res]
    for i in range(0, len(items), 20):
        lines = []
        for name, path in items[i:i + 20]:
            cf_ = f"{W}/c/{tag}/{name}.c"
            if not os.path.exists(cf_):
                res[name] = {"build": "no c"}; continue
            c = open(cf_).read()
            if mem:
                c = mem_patch(c)
                if c is None:
                    res[name] = {"build": "no patch"}; continue
            d = f"{W}/build/{tag}/{name}"; os.makedirs(d, exist_ok=True)
            open(f"{d}/p.c", "w").write(c)
            objc = "-x objective-c -fobjc-arc -fmodules" if re.search(r"^#import ", c, re.M) else ""
            flags = "-DBEND_POISON" if mem else ""
            lines.append(f"cd {d}; echo '@@ {name}'; clang {objc} -std=c11 -O3 -w {flags} p.c -o p -lpthread -lm > cc.txt 2>&1; echo cc=$?")
            for t in ((1, 8) if mem else (None,)):
                th = f"--threads {t} " if t else ""
                k = f"t{t}" if t else "run"
                lines.append(f"cd {W}; [ -x {d}/p ] && {{ perl -e 'alarm {120 if mem else 30}; exec @ARGV' {d}/p +RTS {th}--gpu off -RTS > {d}/{k}.out 2> {d}/{k}.err; echo {k}=$?; }}")
        out = hold("\n".join(lines), 20 * 3000).stdout
        for blk in out.split("@@ ")[1:]:
            name = blk.split("\n", 1)[0].strip(); d = f"{W}/build/{tag}/{name}"
            cc = re.search(r"cc=(\d+)", blk)
            if not cc or cc.group(1) != "0":
                res[name] = {"build": "fail", "err": open(f"{d}/cc.txt").read()[-1500:] if os.path.exists(f"{d}/cc.txt") else ""}; continue
            r = {"build": "ok"}
            for k in (("t1", "t8") if mem else ("run",)):
                m = re.search(rf"^{k}=(\d+)", blk, re.M)
                e = open(f"{d}/{k}.err", errors="replace").read() if os.path.exists(f"{d}/{k}.err") else ""
                live = re.findall(r"^LIVE (-?\d+)$", e, re.M)
                r[k] = {"rc": int(m.group(1)) if m else None, "out": tidy(open(f"{d}/{k}.out", errors="replace").read() if os.path.exists(f"{d}/{k}.out") else "")[-4000:],
                        "err": tidy(re.sub(r"^LIVE -?\d+\n?", "", e, flags=re.M))[-1000:], "live": int(live[-1]) if live else None}
            res[name] = r
        json.dump(res, open(res_f, "w"))
        print("ran", len(res), flush=True)

if __name__ == "__main__":
    a = sys.argv[1:]
    if a[0] == "list": do_list(a[1], a[2])
    elif a[0] == "emit": emit(a[1], a[2], a[3])
    elif a[0] == "derive": derive(a[1], a[2], a[3], a[4])
    elif a[0] == "run": run(a[1], a[2], "--mem" in a, a[a.index("--only") + 1] if "--only" in a else None)
    elif a[0] == "cmp": do_cmp(a[1], a[2], a[3], "--mem" in a, a[4])
