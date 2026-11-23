#!/usr/bin/env python3
"""lane.py: the native lane and the memory check, per compiler tag.

  lane.py list OUT                      write OUT/{tests,benches,demos,kernels,perceus}.list
  lane.py emit ROOT TAG LIST [-j N] [--js]   emit C (or JS) into W/c/TAG/<name>.c
  lane.py run TAG LIST [-j N] [--mem]   build -O3, run +RTS --gpu off -RTS (20 s);
                                        --mem: heap_alloc/heap_free patched to count
                                        live words, -DBEND_POISON, threads 1 and 8.
                                        Results cached by the C's hash in W/cache/.
  lane.py cmp TAGA TAGB LIST [--mem]    status per program; prints the differing ones

LIST lines: "<name> <path>" (path relative to the root the C was emitted from).
"""
import concurrent.futures as cf, hashlib, json, os, re, subprocess, sys, threading

W = "/private/tmp/bend-opt/par/lane"
CACHE = f"{W}/cache"
os.makedirs(CACHE, exist_ok=True)

MEM_HDR = r'''
#include <stdatomic.h>
#include <stdio.h>
static _Atomic long long bend_live_words;
static void bend_live_dump(void) __attribute__((destructor));
static void bend_live_dump(void) { fprintf(stderr, "LIVE %lld\n", (long long)bend_live_words); }
'''


def mem_patch(c):
    c = c.replace("typedef u64 Term;\n", "typedef u64 Term;\n" + MEM_HDR, 1)
    a = "INLINE u64 heap_alloc(Env e, u32 cls) {\n"
    b = "INLINE void heap_free(Env e, u32 cls, u64 loc) {\n  if (err_peek(e.mem)) {\n    return;\n  }\n"
    if a not in c or b not in c or "bend_live_words" not in c:
        return None
    c = c.replace(a, a + "  atomic_fetch_add_explicit(&bend_live_words, 1ll << cls, memory_order_relaxed);\n", 1)
    c = c.replace(b, b + "  atomic_fetch_sub_explicit(&bend_live_words, 1ll << cls, memory_order_relaxed);\n", 1)
    return c


def tidy(s):
    return re.sub(r"[ \t]+$", "", s, flags=re.M).strip()


def want_of(path):
    src = open(path).read()
    return tidy("\n".join(l[2:] for l in src.split("\n") if l.startswith("#|")))


def sh(cmd, cwd=None, timeout=600):
    try:
        p = subprocess.run(cmd, shell=True, cwd=cwd, capture_output=True, text=True,
                           timeout=timeout, errors="replace")
        return p.returncode, p.stdout, p.stderr
    except subprocess.TimeoutExpired:
        return "timeout", "", ""


BASE_RE = re.compile(r"^(?:[\t\r ]*(?:(?:#|import[\t ])[^\n]*)?\n)*[\t ]*import[\t ]+Base(?=[\t\r ]*(?:#|\n|$))")


def do_list(out, root):
    tests = []
    for d, _, fs in os.walk(f"{root}/tests"):
        for f in sorted(fs):
            if not f.endswith(".bend"):
                continue
            p = os.path.join(d, f)
            src = open(p).read()
            want = tidy("\n".join(l[2:] for l in src.split("\n") if l.startswith("#|")))
            if not any(l.startswith("#|") for l in src.split("\n")):
                continue
            effs = re.findall(r'^\s*import "\./[a-z0-9_]+\.(c|js)"$', src, re.M)
            c_lane = BASE_RE.search(src) and (not effs or "c" in effs)
            js_lane = BASE_RE.search(src) and (not effs or "js" in effs)
            main = re.search(r"^(def|law) main(\(|:)", src, re.M)
            fails = re.match(r"^(SOME PROOFS FAIL|Error:)", want)
            rel = os.path.relpath(p, root)
            name = rel[len("tests/"):-len(".bend")].replace("/", "__")
            if main and not fails:
                if c_lane:
                    tests.append(f"{name} {rel}")
    open(out, "w").write("\n".join(sorted(tests)) + "\n")
    print("tests", len(tests))


def emit_one(root, tag, name, path, js):
    ext = "js" if js else "c"
    dst = f"{W}/c/{tag}/{name}.{ext}"
    if os.path.exists(dst):
        return name, "cached"
    rc, o, e = sh(f"bun {root}/bend2/main.ts {path} -o {dst}.tmp.{ext}", cwd=root, timeout=600)
    if rc == 0 and os.path.exists(f"{dst}.tmp.{ext}"):
        os.rename(f"{dst}.tmp.{ext}", dst)
        return name, "ok"
    open(f"{W}/c/{tag}/{name}.emitfail", "w").write(f"{rc}\n{o}\n{e}")
    return name, f"fail {rc}"


def read_list(lst):
    return [l.split() for l in open(lst) if l.strip()]


def do_emit(root, tag, lst, j, js):
    os.makedirs(f"{W}/c/{tag}", exist_ok=True)
    items = read_list(lst)
    n = 0
    with cf.ThreadPoolExecutor(j) as ex:
        for name, st in ex.map(lambda x: emit_one(root, tag, x[0], x[1], js), items):
            n += 1
            if st.startswith("fail"):
                print("EMITFAIL", name, st, flush=True)
    print("emitted", n)


def build_run(cfile, mem, cwd):
    c = open(cfile).read()
    h = hashlib.sha1((c + ("MEM" if mem else "")).encode()).hexdigest()
    cp = f"{CACHE}/{h}.json"
    if os.path.exists(cp):
        return json.load(open(cp))
    d = f"{W}/build/{h}.{os.getpid()}.{threading.get_ident()}"
    os.makedirs(d, exist_ok=True)
    if mem:
        c2 = mem_patch(c)
        if c2 is None:
            r = {"build": "no patch"}
            json.dump(r, open(cp, "w"))
            return r
        c = c2
    open(f"{d}/p.c", "w").write(c)
    objc = "-x objective-c -fobjc-arc -fmodules" if re.search(r"^#import ", c, re.M) else ""
    flags = "-DBEND_POISON" if mem else ""
    rc, o, e = sh(f"clang {objc} -std=c11 -O3 -w {flags} p.c -o p -lpthread -lm", cwd=d, timeout=900)
    if rc != 0:
        r = {"build": f"fail {rc}", "err": e[-2000:]}
    else:
        r = {"build": "ok"}
        for t in ((1, 8) if mem else (None,)):
            th = f"--threads {t} " if t else ""
            rc, o, e = sh(f"perl -e 'alarm {120 if mem else 30}; exec @ARGV' {d}/p +RTS {th}--gpu off -RTS", cwd=cwd, timeout=200)
            k = f"t{t}" if t else "run"
            live = re.findall(r"^LIVE (-?\d+)$", e, re.M)
            r[k] = {"rc": rc, "out": tidy(o)[-4000:], "err": tidy(re.sub(r"^LIVE -?\d+\n?", "", e, flags=re.M))[-1000:],
                    "live": int(live[-1]) if live else None}
    json.dump(r, open(cp, "w"))
    sh(f"rm -rf {d}")
    return r


def do_run(tag, lst, j, mem, cwd):
    items = read_list(lst)
    res = {}
    def one(x):
        name = x[0]
        cf_ = f"{W}/c/{tag}/{name}.c"
        if not os.path.exists(cf_):
            return name, {"build": "no c"}
        return name, build_run(cf_, mem, cwd)
    with cf.ThreadPoolExecutor(j) as ex:
        for name, r in ex.map(one, items):
            res[name] = r
    suf = "mem" if mem else "run"
    json.dump(res, open(f"{W}/c/{tag}.{os.path.basename(lst)}.{suf}.json", "w"))
    print("ran", len(res))


def status(r, want, mem):
    if r.get("build") != "ok":
        return "build:" + r.get("build", "?")
    if mem:
        return " ".join(f"t{t}:{'ok' if r[f't{t}']['out'] == want else 'BAD'}:rc{r[f't{t}']['rc']}:live{r[f't{t}']['live']}" for t in (1, 8))
    rr = r["run"]
    return ("pass" if rr["out"] == want else "FAIL") + f":rc{rr['rc']}"


def do_cmp(a, b, lst, mem, root):
    suf = "mem" if mem else "run"
    ra = json.load(open(f"{W}/c/{a}.{os.path.basename(lst)}.{suf}.json"))
    rb = json.load(open(f"{W}/c/{b}.{os.path.basename(lst)}.{suf}.json"))
    items = read_list(lst)
    same = diff = 0
    counts = {}
    for name, path in items:
        want = want_of(f"{root}/{path}") if path.startswith("tests/") else None
        if want is None:
            # programs without #| lines: compare A's output with B's
            want = (ra.get(name, {}).get("t1" if mem else "run") or {}).get("out")
        sa = status(ra[name], want, mem) if name in ra else "absent"
        sb = status(rb[name], want, mem) if name in rb else "absent"
        counts[sb.split(":")[0]] = counts.get(sb.split(":")[0], 0) + 1
        if sa == sb:
            same += 1
        else:
            diff += 1
            print(f"DIFF {name}: {a}={sa}  {b}={sb}")
    print(f"same {same} differ {diff}; {b} statuses {counts}")


if __name__ == "__main__":
    a = sys.argv[1:]
    j = int(a[a.index("-j") + 1]) if "-j" in a else 4
    flags = [x for x in a if x.startswith("--")]
    pos = [x for i, x in enumerate(a) if not x.startswith("--") and x != "-j" and (i == 0 or a[i - 1] != "-j")]
    cmd = pos[0]
    if cmd == "list":
        do_list(pos[1], pos[2])
    elif cmd == "emit":
        do_emit(pos[1], pos[2], pos[3], j, "--js" in flags)
    elif cmd == "run":
        do_run(pos[1], pos[2], j, "--mem" in flags, pos[3] if len(pos) > 3 else W)
    elif cmd == "cmp":
        do_cmp(pos[1], pos[2], pos[3], "--mem" in flags, pos[4] if len(pos) > 4 else "/private/tmp/bend-opt/m230/main")
