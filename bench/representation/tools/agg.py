#!/usr/bin/env python3
"""agg.py CNTDIR: the reach tables from the rep hook's records."""
import json, glob, collections, sys, os
d = sys.argv[1]
grp = lambda f: os.path.basename(f).split(".")[0] if not os.path.basename(f).startswith("tchunk") else "tests"
R = collections.defaultdict(list)
for f in sorted(glob.glob(f"{d}/*.jsonl")):
    for l in open(f):
        o = json.loads(l); o["grp"] = grp(f); R[o["kind"]].append(o)
files = {(o["grp"], o["file"]) for k in R for o in R[k] if k != "fail"}
fails = {o["file"] for o in R["fail"]}
print("files with records:", len(files), " failing to check:", len(fails), " hook errors:", len(R["err"]))
for e in R["err"][:5]: print("  err", e.get("file"), e.get("def") or e.get("fam"), e["msg"][:120])
adts = R["adt"]
print("types:", len(adts), " recursive:", sum(a["rec"] for a in adts), " words:", sum(not a["rec"] for a in adts))
w = [a for a in adts if a["wrapper"]]
print("one-constructor one-field types:", len(w), " words (already erased):", sum(not a["rec"] for a in w),
      " heap nodes:", sum(a["rec"] for a in w))
for a in w:
    if a["rec"]: print("   rec wrapper", a["grp"], a["file"].split("/")[-2:], a["fam"], a["reached"])
ly = [a for a in adts if a["listy"]]
print("list-like types:", len(ly), " reached from a main:", sum(bool(a["reached"]) for a in ly))
for a in ly:
    if a["reached"] and a["grp"] in ("benches", "kernels", "par", "perceus", "base"): print("   listy", a["grp"], "/".join(a["file"].split("/")[-2:]), a["fam"])
rw = [a for a in adts if a["rw"] and a["rw"][1] < a["rw"][0]]
print("records whose tag/w32 words could share 56-bit words:", len(rw), " of", sum(1 for a in adts if a["rw"]))
by = collections.Counter(a["grp"] for a in rw); print("   by group", dict(by))
for a in rw:
    if a["grp"] in ("benches", "kernels", "par", "perceus", "base"): print("   rec", a["grp"], "/".join(a["file"].split("/")[-2:]), a["fam"], a["rw"])
cs = R["ctr"]
small = [c for c in cs if c["small"] > 0]
hits = [c for c in cs if c["pack"] is not None]
print("node constructors:", len(cs), " with a tag word:", len(small), " packing drops a class:", len(hits),
      " fixed by foreign C (not packed):", sum(c["fixed"] for c in cs if c["small"]))
would = [c for c in cs if c["fixed"] and c["small"]]
for c in would: print("   fixed", c["grp"], "/".join(c["file"].split("/")[-2:]), c["ctr"], c["bits"])
print("   hits by group", dict(collections.Counter(c["grp"] for c in hits)), " reached:", sum(bool(c["reached"]) for c in hits))
for c in hits:
    print("   hit", c["grp"], "/".join(c["file"].split("/")[-2:]), c["ctr"], c["bits"], f'{c["words"]}->{c["pack"]} cls {c["cls"]}->{c["cls2"]}', "reached" if c["reached"] else "")
nd = [c for c in cs if c["small"] and c["pack"] is None and not c["fixed"]]
print("node ctrs with a tag word, no class drop:", len(nd))
ds = R["def"]
for k in ("clo", "eta", "app"):
    print(f"defs with {k}:", sum(1 for o in ds if o[k]), " sites:", sum(o[k] for o in ds),
          " in reached defs:", sum(o[k] for o in ds if o["reached"]))
print("closure sites by group:", dict(collections.Counter({g: sum(o["clo"] for o in ds if o["grp"] == g) for g in set(o["grp"] for o in ds)})))
