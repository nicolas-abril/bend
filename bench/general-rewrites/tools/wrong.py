#!/usr/bin/env python3
"""wrong.py: each mutation of opt/trmc's comp.ts, built into its own copy of
bend2, compiles the new tests; each must fail its #| lines, leak (live words)
or crash in the memory check, at 1 or 8 threads."""
import os, shutil, subprocess, sys, importlib.util
G = "/private/tmp/bend-opt/gen"
spec = importlib.util.spec_from_file_location("lane", f"{G}/tools/lane.py")
lane = importlib.util.module_from_spec(spec); spec.loader.exec_module(lane)
L = os.path.expanduser("~/Software/supgen-bend/limit")
TESTS = ["tmc_dest", "tmc_dest_shared", "acc_monoids", "ctor_tail_dest", "ctor_tail_dest_bang", "ctor_tail_dest_lend"]
M = {
 "w1_no_seal": ("e.mem[dh & ~(1ull << 63)] = dh >> 63 ? rfc_seal(e, (X)) : (X);", "e.mem[dh & ~(1ull << 63)] = (X);"),
 "w2_unpacked_slot": ("return { at: `${pk ? pk.at[w][0] : w}, ", "return { at: `${w}, "),
 "w3_no_own_check": ("if (j < 0 || ls[j] !== BOX || [...sc.uses].some(([q, d]) => own(q, d))) {", "if (j < 0 || ls[j] !== BOX) {"),
 "w4_no_hole_move": ("  STK(-2) = (term_loc(R) + (J)) | ((u64)(S) << 63); \\\n", ""),
 "w5_no_dead": ("  const r = emit_alias(sc, val_own(emit_expr(sc, b, null, BOX))[0], \"r\");\n  bind_dead(sc, []);", "  const r = emit_alias(sc, val_own(emit_expr(sc, b, null, BOX))[0], \"r\");"),
 "w6_mul_unit0": ("\"U32.mul\": u(\"U32\", 1)", "\"U32.mul\": u(\"U32\", 0)"),
 "w7_and_unit0": ("\"U32.and\": u(\"U32\", 0xFFFFFFFF)", "\"U32.and\": u(\"U32\", 0)"),
 "w8_spare_kept": ("  const spares = fit < 0 ? [] : sc.spares.splice(fit, 1);", "  const spares = fit < 0 ? [] : sc.spares.slice(fit, fit + 1);"),
 "w9_use_twice": ("|| ret_at(c.k!) >= 0 || rest_use([b], p) !== 1 ||", "|| ret_at(c.k!) >= 0 ||"),
 "w10_seal_bit_off": ("return { at: `${pk ? pk.at[w][0] : w}, ${Number(fact(\"ctr\", x.k))}`,", "return { at: `${pk ? pk.at[w][0] : w}, 0`,"),
}
want = {t: lane.want_of(f"{G}/trmc/tests/run/{t}.bend") for t in TESTS}
for name, (a, b) in M.items():
    if len(sys.argv) > 1 and name not in sys.argv[1:]:
        continue
    d = f"{G}/wrong/{name}"
    shutil.rmtree(d, ignore_errors=True)
    shutil.copytree(f"{G}/trmc/bend2", f"{d}/bend2")
    src = open(f"{d}/bend2/comp.ts").read()
    assert src.count(a) == 1, name
    open(f"{d}/bend2/comp.ts", "w").write(src.replace(a, b))
    res = []
    for t in TESTS:
        c = f"{d}/{t}.c"
        r = subprocess.run([L, "300", "6144", "bun", f"{d}/bend2/main.ts", f"{G}/trmc/tests/run/{t}.bend", "-o", c], capture_output=True, text=True)
        if r.returncode:
            res.append(f"{t}:emitfail"); continue
        mc = lane.mem_patch(open(c).read())
        open(c + ".m.c", "w").write(mc)
        if subprocess.run([L, "600", "6144", "cc", "-std=c11", "-O3", "-w", "-DBEND_POISON", c + ".m.c", "-o", c + ".bin", "-lpthread", "-lm"], capture_output=True).returncode:
            res.append(f"{t}:CAUGHT build fails"); continue
        bad = []
        for th in (1, 8):
            p = subprocess.run([L, "60", "6144", c + ".bin", "+RTS", "--threads", str(th), "--gpu", "off", "-RTS"], capture_output=True, text=True)
            live = [l for l in p.stderr.split("\n") if l.startswith("LIVE")]
            if lane.tidy(p.stdout) != want[t]: bad.append(f"t{th}:out")
            if p.returncode: bad.append(f"t{th}:rc{p.returncode}")
            if live and live[-1] != "LIVE 0": bad.append(f"t{th}:{live[-1]}")
        res.append(f"{t}:{'CAUGHT ' + ','.join(bad) if bad else 'ok'}")
    print(name, " | ".join(res), flush=True)
