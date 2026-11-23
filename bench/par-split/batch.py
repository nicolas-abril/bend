#!/usr/bin/env python3 -I
# batch.py JOBS.json: each job (exe, threads, meta) through one.py, in order; JSON lines out. Runs inside the lock.
import json, os, subprocess, sys
H = os.path.dirname(os.path.abspath(__file__))
for j in json.load(open(sys.argv[1])):
    p = subprocess.run(["python3", "-I", f"{H}/one.py", j["exe"], str(j["threads"])], capture_output=True, text=True)
    try: rec = json.loads(p.stdout.strip().splitlines()[-1])
    except Exception: rec = {"rc": "fail"}
    rec["meta"] = j["meta"]
    print(json.dumps(rec), flush=True)
