#!/usr/bin/env python3
"""mutants.py: wrong versions of the lazy-split runtime, each checked against the
lazy-split tests at 1, 2, 4 and 10 threads (3 runs each). Emits the tests with the
split checkout, applies each mutation to the C, builds and runs, all in one hold of
one call of tools/heavy.sh (lock, free memory, 4096 MB). Prints which mutants the tests catch."""
import os, re, subprocess
S = "/private/tmp/bend-opt/par/split"; D = "/private/tmp/bend-opt/par/mut"
L = os.path.expanduser("~/Software/supgen-bend/limit")
tests = ["lazy_split_deep", "lazy_split_unbal", "lazy_split_results", "lazy_split_shared", "fork_exit_turns"]
MUT = {
  "ok": [],
  "split-newest": [("  if (lo >= hi || ~bits == 0 || err_seen(e.mem)) {", "  lo = hi;\n  if (~bits == 0 || err_seen(e.mem)) {")],
  "no-wait": [("    fk_help(e, sp, a32_at(e.mem, task_tail(fut) + 1));", "    (void)0;")],
  "no-drop": [("#define WL_FKDROP       if (seq & FK_SEQ) { fk_drop(e); }", "#define WL_FKDROP")],
  "result-word": [("      r0 = fk_v[0];", "      r0 = fk_v[1];")],
  "no-reclaim": [("  if (__atomic_compare_exchange_n(&fk_box[me][t->slot], &tk, 0, false,", "  if (0 && __atomic_compare_exchange_n(&fk_box[me][t->slot], &tk, 0, false,")],
  "steal-no-cas": [("      if (t != 0 && __atomic_compare_exchange_n(&fk_box[w][s], &t, 0, false,\n          __ATOMIC_ACQ_REL, __ATOMIC_RELAXED)) {", "      if (t != 0) {")],
  "no-gap": [("  if (now < e.alc[FK_NEXT]) {", "  if (0) {")],
  "early-done": [("        fk_help(e, stk, NULL);\n", "")],
}
os.makedirs(D, exist_ok=True)
sh = []
for t in tests:
    if os.path.exists(f"{D}/{t}.c"): continue
    sh.append(f"cd {S}; BUN_JSC_forceRAMSize=3000000000 bun bend2/main.ts tests/run/{t}.bend -o {D}/{t}.c > /dev/null 2>&1 || echo EMITFAIL {t}")
sh and subprocess.run(["/Users/macolas/Software/bend-benchmarks/tools/heavy.sh", "1800", "4096", "--", "bash", "-c", "\n".join(sh)])
want = {t: "\n".join(l[2:] for l in open(f"{S}/tests/run/{t}.bend").read().split("\n") if l.startswith("#|")).strip() for t in tests}
sh = []
for m, eds in MUT.items():
    for t in tests:
        c = open(f"{D}/{t}.c").read()
        for a, b in eds:
            # the pattern is in the runtime text, which every test carries
            if a not in c:
                raise SystemExit(f"mutant {m}: pattern not found in {t}: {a[:50]}")
            c = c.replace(a, b, 1)
        open(f"{D}/{m}.{t}.c", "w").write(c)
        sh.append(f"cc -std=c11 -O3 -w {D}/{m}.{t}.c -o {D}/{m}.{t} -lpthread || echo CCFAIL {m} {t}")
        for th in (1, 2, 4, 10):
            for r in range(3):
                sh.append(f"echo \"@@ {m} {t} {th} $(perl -e 'alarm 20; exec @ARGV' {D}/{m}.{t} +RTS --threads {th} --gpu off -RTS 2>&1 | tr '\\n' ' ' | cut -c1-80)\"")
# one heavy call per mutant: a mutant that eats memory is killed alone
out = ""
for m in MUT:
    part = [l for l in sh if f"{D}/{m}." in l]
    r = subprocess.run(["/Users/macolas/Software/bend-benchmarks/tools/heavy.sh", "1800", "4096", "--", "bash", "-c", "\n".join(part)], capture_output=True, text=True)
    out += r.stdout
    if r.returncode: print(f"{m}: the heavy call ended with {r.returncode} (cap or timeout)", r.stderr[-200:].strip())
res = {}
for l in out.splitlines():
    if l.startswith("@@ "):
        _, m, t, th, *o = l.split(" ")
        got = " ".join(o).strip()
        res.setdefault(m, []).append((t, th, got == want[t], got))
    else:
        print(l)
for m, rs in res.items():
    bad = [r for r in rs if not r[2]]
    print(f"{m:14s} {'CAUGHT' if bad else 'not caught'} ({len(bad)} of {len(rs)} runs wrong)" + (f" e.g. {bad[0][0]} t{bad[0][1]}: {bad[0][3][:60]}" if bad else ""))
