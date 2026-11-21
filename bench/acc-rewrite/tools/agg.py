#!/usr/bin/env python3
"""agg.py DIR: the reach of the two steps over the hook's output.

DIR holds GROUP.jsonl files (one per corpus group: base is the BASE records
of any of them). Prints the counts and the hit lists as Markdown.

Step 1: a match chain is a hit when, for a nullary C0 and a C with fields,
C0's arm equals C's with C's fields replaced by constants (plain: no
rewriting; ident: under the arithmetic identities), C0{} read as C{...}. It
holds at every consumer when every match on the type in the program (its
defs reachable from main, Base's included; the whole file and Base when there
is no main; Base alone for Base) accepts one same constant tuple ("*" accepts
any).
Step 2: a call one of whose arguments is a call to a def; a hit when the
outer callee's parameter there is used, on every path, only as an operand of
an add into another value (pk lam: the word itself, as #2175; pk mat: the
fields of the matched record, as `queens`).
"""
import collections, glob, json, os, re, sys

d = sys.argv[1]
GROUPS = ["benches", "demos", "kernels", "par", "perceus", "tests"]
groups = {g: [json.loads(l) for l in open(f"{d}/{g}.jsonl") if l.strip()] for g in GROUPS}

# Base's records once (every run writes them first)
base = [r for r in groups["benches"] if r["file"] == "BASE"]
prog = collections.defaultdict(list)  # (group, file) -> records
for g, rs in groups.items():
    for r in rs:
        if r["file"] != "BASE":
            prog[(g, r["file"])].append(r)
prog[("base", "BASE")] = base

base_by_def = collections.defaultdict(list)
for r in base:
    if "def" in r:
        base_by_def[r["def"]].append(r)
base_adts = {r["fam"]: r["ctrs"] for r in base if r["kind"] == "adt"}


def short(f):
    for a, b in (("/private/tmp/bend-opt/acc2/main/", ""),
                 ("/private/tmp/bend-opt/acc2/perc/", "[bench/perceus] "),
                 ("/Users/macolas/Software/koru-benchmarks/suites/osprey-compute-kernels/", "koru/")):
        if f.startswith(a):
            return b + f[len(a):]
    return f


def consumers(key):
    """the match records of a program (own and Base's) that its main reaches"""
    rs = prog[key]
    fails = [r for r in rs if r["kind"] == "fail"]
    if fails:
        return None, None
    reach = next((set(r["defs"]) for r in rs if r["kind"] == "reach"), None)
    own = [r for r in rs if r["kind"] == "mat" and not r.get("skip")]
    if key[1] == "BASE":
        return own, None
    bs = [r for k, v in base_by_def.items() for r in v
          if r["kind"] == "mat" and not r.get("skip") and (reach is None or k in reach)]
    if reach is not None:
        own = [r for r in own if r["def"] in reach]
    return own + bs, reach


def fits(tuples, t):
    return any(all(a == "*" or b == "*" or a == b for a, b in zip(u, t)) for u in tuples)


def common(cons, c0, c):
    """a constant tuple every consumer of the type accepts, or None"""
    cand = None
    for r in cons:
        e = next((x for x in r.get("res", []) if x["c0"] == c0 and x["c"] == c), None)
        if e is not None:
            e = dict(e, ident=[] if e.get("rec") else [t for t in e["ident"] if c0 not in t])
        if e is None:
            # C0 or C has no arm here (impossible by typing) or no fields
            continue
        if not e["ident"]:
            return None, r
        if cand is None:
            cand = e["ident"]
        else:
            cand = [t for t in cand if fits(e["ident"], t)] or \
                   [u for u in e["ident"] if fits(cand, u)]
            if not cand:
                return None, r
    return cand, None


out = []
P = out.append

# ---------- step 1 ----------
tot = collections.Counter()
hits = []
seen_base = set()
DUP = set()


def dup(key, r):
    """a record seen already from another file of the same directory (an
    imported module's def): counted once"""
    k = (key[0], os.path.dirname(key[1]), json.dumps({a: b for a, b in r.items() if a != "file"}, sort_keys=True))
    # an imported module's names carry its prefix (main:f, bend3d:T)
    k = (k[0], k[1], re.sub(r'"[A-Za-z0-9_]+:', '"', k[2]))
    if k in DUP:
        return True
    DUP.add(k)
    return False


for key, rs in prog.items():
    if any(r["kind"] == "fail" for r in rs):
        tot["files failing to check"] += 1
        continue
    tot["files checked"] += 1
    cons, reach = consumers(key)
    for r in rs:
        if r["kind"] != "mat" or dup(key, r):
            continue
        tot["match chains"] += 1
        if r.get("skip"):
            tot["  on a builtin (Nat, U32, Bool, ...): not counted"] += 1
            continue
        tot["  on a declared type"] += 1
        cs = r["ctrs"] or []
        if not any(c.endswith("/0") for c in cs):
            continue
        tot["    whose type has a nullary constructor"] += 1
        if not any(not c.endswith("/0") for c in cs):
            continue
        tot["      and a constructor with fields (eligible)"] += 1
        tot[f"        eligible, scrutinee {r['scrut']}"] += 1
        if all(e.get("rec") for e in r.get("res", [])):
            tot["        eligible but every C with fields holds a T (recursive)"] += 1
        res = r.get("res", [])
        for e in res:
            for m in ("plain", "ident", "broad"):
                e[m] = [t for t in e[m] if e["c0"] not in t]
        if any(e.get("rec") and (e["ident"] or e["broad"]) for e in res):
            tot["        hit only through a field of the type's own type (recursive: dropped)"] += 1
        res = [e for e in res if not e.get("rec")]
        p = any(e["plain"] for e in res)
        i = any(e["ident"] for e in res)
        b = any(e["broad"] for e in res)
        tot["        hit, constants, no identities"] += p
        tot["        hit, constants + identities"] += i
        tot["        hit, constants or variables + identities (broad)"] += b
        if i or b:
            for e in res:
                if not (e["ident"] or e["broad"]):
                    continue
                cand, bad = common(cons, e["c0"], e["c"]) if cons is not None else (None, None)
                hits.append(dict(group=key[0], file=short(key[1]), def_=r["def"], fam=r["fam"],
                                 c0=e["c0"], c=e["c"], plain=bool(e["plain"]), ident=e["ident"][:1],
                                 broad=e["broad"][:1] if not e["ident"] else [],
                                 every=cand[:1] if cand else None,
                                 bad=(bad["def"] if bad else None),
                                 reach=(reach is not None and r["def"] in reach) if key[1] != "BASE" else None,
                                 trivial=all(x == "*" for x in (e["ident"][0] if e["ident"] else ["x"]))))
                break

P("## Step 1: a nullary constructor that acts as a constant\n")
P("Match chains over every runnable def (Base once; every other file its own defs).\n")
P("| | count |\n|---|---:|")
for k, v in tot.items():
    P(f"| {k} | {v} |")

# group hits by (file, def, fam): a source match is several chains
agg = collections.OrderedDict()
for h in hits:
    k = (h["group"], h["file"], h["def_"], h["fam"], h["c0"], h["c"])
    a = agg.setdefault(k, dict(h, chains=0, triv=0, nident=0, nbroad=0, nplain=0))
    a["chains"] += 1
    a["triv"] += h["trivial"]
    a["nident"] += bool(h["ident"])
    a["nplain"] += h["plain"]
    a["nbroad"] += bool(h["broad"])
    if a["every"] is None or h["every"] is None:
        a["every"] = None
        a["bad"] = a["bad"] or h["bad"]

P("\nHits by def (chains = match chains in the core; triv = chains where C0's arm equals C's for any constants,"
  " i.e. the match re-forms its scrutinee or ignores the fields; every = the constant tuple every consumer of the"
  " type in the program accepts, or the first def that refuses):\n")
P("| group | file | def | type | C0 -> C | chains | triv | plain | ident | broad only | at every consumer | reached from main |")
P("|---|---|---|---|---|---:|---:|---:|---:|---:|---|---|")
ntriv = sum(1 for a in agg.values() if a["triv"] == a["chains"])
P(f"(Of {len(agg)} rows, {ntriv} are trivial in every chain: the match re-forms its scrutinee or ignores the fields,"
  " so any constants do; they are listed after the others.)\n")
for k, a in sorted(agg.items(), key=lambda kv: (kv[1]["triv"] == kv[1]["chains"], kv[1]["group"] == "tests", kv[0])):
    ev = ("yes " + ",".join(a["every"][0])) if a["every"] else (f"no ({a['bad']})" if a["bad"] else "no")
    P(f"| {a['group']} | {a['file']} | {a['def_']} | {a['fam']} | {a['c0']} -> {a['c']} | {a['chains']} | {a['triv']} |"
      f" {a['nplain']} | {a['nident']} | {a['nbroad']} | {ev} | {a['reach']} |")

# ---------- step 2 ----------
t2 = collections.Counter()
h2 = collections.OrderedDict()
for key, rs in prog.items():
    if any(r["kind"] == "fail" for r in rs):
        continue
    reach = next((set(r["defs"]) for r in rs if r["kind"] == "reach"), None)
    for r in rs:
        if r["kind"] != "call2":
            continue
        if dup(key, r):
            # the same call in another file of the directory: it may be reached there
            for (g, f, de, o, i, pos), a in h2.items():
                if g == key[0] and os.path.dirname(f) == os.path.dirname(short(key[1])) and \
                        re.sub(r"^\w+:", "", de) == re.sub(r"^\w+:", "", r["def"]) and pos == r["pos"] and reach is not None:
                    a["reach"] = a["reach"] or (r["def"] in reach)
            continue
        t2["calls with a call to a def as an argument"] += 1
        u = r.get("use")
        pk = r.get("pk")
        t2[f"  parameter taken as {pk}"] += 1
        if u == "add":
            t2[f"    used only as an add into another value ({pk})"] += 1
        if u in ("add", "assoc"):
            t2[f"    used only as an associative op into another value ({pk})"] += 1
        if u in ("add", "assoc"):
            k = (key[0], short(key[1]), r["def"], r["outer"], r["inner"], r["pos"])
            a = h2.setdefault(k, dict(n=0, pk=pk, use=u, fam=r.get("fam"), retc0=r.get("retc0"),
                                      reach=(reach is not None and r["def"] in reach) if key[1] != "BASE" else None))
            a["n"] += 1

P("\n## Step 2: a returned record whose fields are only added into parameters\n")
P("| | count |\n|---|---:|")
for k, v in t2.items():
    P(f"| {k} | {v} |")
P("\nHits (use add) and near hits (use assoc: or, xor, mul, and, min, max as well):\n")
P("| group | file | def | outer(inner) at arg | sites | param | type | use | inner may return a nullary ctor | reached from main |")
P("|---|---|---|---|---:|---|---|---|---|---|")
for (g, f, de, o, i, pos), a in h2.items():
    P(f"| {g} | {f} | {de} | {o}({i}) at {pos} | {a['n']} | {a['pk']} | {a['fam'] or ''} | {a['use']} | {','.join(a['retc0']) or 'no'} | {a['reach']} |")

# ---------- broader family ----------
P("\n## The broader family: types with an absent / present constructor\n")
fams = {}
for key, rs in prog.items():
    for r in rs:
        if r["kind"] == "adt":
            fams.setdefault(r["fam"], (key, r["ctrs"]))
opt = {f: v for f, v in fams.items() if any(c.endswith("/0") for c in v[1]) and any(not c.endswith("/0") for c in v[1])}
opt2 = {f: v for f, v in opt.items() if len(v[1]) == 2}
P(f"Declared types (Base once, then each file's own): {len(fams)}; with a nullary constructor and one with fields: {len(opt)};"
  f" Option-shaped (exactly those two): {len(opt2)}.\n")
bf = collections.Counter()
alongside = collections.OrderedDict()
for key, rs in prog.items():
    if any(r["kind"] == "fail" for r in rs):
        continue
    for r in rs:
        if r["kind"] != "mat" or r.get("skip") or dup(("bf",) + key[1:] if False else (key[0] + "/bf", key[1]), r):
            continue
        cs = r["ctrs"] or []
        if not (any(c.endswith("/0") for c in cs) and any(not c.endswith("/0") for c in cs)):
            continue
        if r.get("res") and all(e.get("rec") for e in r["res"]):
            bf["matches on a recursive type with a nullary end (list-like): not the family"] += 1
            continue
        shape = "option" if len(cs) == 2 else "wider"
        bf[f"matches on a {shape}-shaped type"] += 1
        res = r.get("res", [])
        if any(e["ident"] for e in res):
            bf[f"  {shape}: C0 is C with constant fields (step 1)"] += 1
        elif any(e["broad"] for e in res):
            bf[f"  {shape}: C0 is C with fields from variables in scope (default)"] += 1
        fu = r.get("fuse", {})
        uses = [u for v in fu.values() for u in v]
        if uses and all(u in ("add", "assoc", "unused") for u in uses) and any(u != "unused" for u in uses):
            bf[f"  {shape}: fields only combined into other values (alongside)"] += 1
            k = (key[0], short(key[1]), r["def"], r["fam"])
            alongside[k] = alongside.get(k, 0) + 1
P("| | count |\n|---|---:|")
for k, v in bf.items():
    P(f"| {k} | {v} |")
P("\nOption-shaped types:\n")
P(", ".join(sorted(f"{f} ({short(v[0][1])})" for f, v in opt2.items())))
P("\nMatches whose fields are only combined into other values (the `ret` shape):\n")
P("| group | file | def | type | chains |\n|---|---|---|---|---:|")
for (g, f, de, fam), n in alongside.items():
    P(f"| {g} | {f} | {de} | {fam} | {n} |")

errs = [(k, r["def"], r["msg"][:80]) for k, rs in prog.items() for r in rs if r["kind"] == "err"]
fails = [(k, r["msg"][:100]) for k, rs in prog.items() for r in rs if r["kind"] == "fail"]
P(f"\nHook errors: {len(errs)}; files that did not check: {len(fails)}")
for (k, de, m) in errs[:20]:
    P(f"- err {short(k[1])} {de}: {m}")
print("\n".join(out))
