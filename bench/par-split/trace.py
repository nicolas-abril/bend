#!/usr/bin/env python3
"""trace.py TRACE [--c PROG.c] [--timeline]: summarise a PAR_TRACE dump.

wall; main thread before / in / after cube_run; grow and drain turns (count,
wall, work, idle = threads x wall - work, busiest thread); a busy-workers
profile (share of wall with k workers inside a task); seq task time; the
longest tasks with the fid they started at (names from --c).
"""
import bisect, re, struct, sys

def load(path):
    b = open(path, "rb").read()
    magic, nth = struct.unpack_from("<II", b, 0)
    t_start, t_end, frq = struct.unpack_from("<QQQ", b, 8)
    off, evs, drops = 32, [], 0
    for w in range(nth):
        n, drop = struct.unpack_from("<IQ", b, off); off += 12; drops += drop
        for i in range(n):
            t0, dur, kind, aux = struct.unpack_from("<QIHH", b, off); off += 16
            evs.append((t0 - t_start, dur, kind, aux, w))
    return nth, t_end - t_start, frq, evs, drops

a = sys.argv
nth, wall, frq, evs, drops = load(a[1])
ms = lambda t: t * 1000.0 / frq
names = {}
if "--c" in a:
    for l in open(a[a.index("--c") + 1]):
        m = re.match(r"#define (FID_\w+) (\d+)$", l.strip())
        if m: names[int(m.group(2))] = m.group(1)
tasks = sorted(e for e in evs if e[2] == 0)
turns = sorted(e for e in evs if e[2] in (1, 2))
cubes = [e for e in evs if e[2] == 3]
cube_t = sum(e[1] for e in cubes)
first = min((e[0] for e in cubes), default=wall)
last = max((e[0] + e[1] for e in cubes), default=wall)
print(f"threads {nth}  wall {ms(wall):.1f} ms  drops {drops}")
print(f"main: before first cube_run {ms(first):.1f} ms, in cube_run {ms(cube_t):.1f} ms ({len(cubes)} runs), after {ms(wall - last):.1f} ms")
starts = [t[0] for t in turns]
per = [dict(n=0, work=[0] * nth, longest=0) for _ in turns]
for (t0, dur, kind, aux, w) in tasks:
    i = bisect.bisect_right(starts, t0) - 1
    if i >= 0 and t0 < turns[i][0] + turns[i][1]:
        p = per[i]; p["n"] += 1; p["work"][w] += dur; p["longest"] = max(p["longest"], dur)
for g, name in ((1, "grow"), (2, "drain")):
    idx = [i for i, t in enumerate(turns) if t[2] == g]
    if not idx: continue
    tw = sum(turns[i][1] for i in idx); work = sum(sum(per[i]["work"]) for i in idx)
    print(f"{name}: {len(idx)} turns, wall {ms(tw):.1f} ms, work {ms(work):.1f} ms, idle {ms(nth * tw - work):.1f} ms"
          f" (eff {work / max(nth * tw, 1):.2f}), busiest-thread sum {ms(sum(max(per[i]['work']) for i in idx)):.1f} ms")
pts = sorted([(t[0], 1) for t in tasks] + [(t[0] + t[1], -1) for t in tasks])
hist = [0] * (nth + 2); cur = lt = 0
for t, d in pts:
    hist[min(cur, nth + 1)] += t - lt; cur += d; lt = t
hist[0] += wall - lt
print("busy-workers profile (% of wall): " + " ".join(f"{k}:{100 * hist[k] / wall:.0f}" for k in range(nth + 1) if hist[k] > 0))
tot = sum(t[1] for t in tasks)
print(f"task time {ms(tot):.1f} ms ({len(tasks)} tasks): seq {ms(sum(t[1] for t in tasks if t[3] & 1)):.1f} ms, on P-cores {100 * sum(t[1] for t in tasks if t[3] & 8) / max(tot, 1):.0f}%")
print("longest tasks: " + ", ".join(f"{ms(t[1]):.1f} ms (w{t[4]}, {'seq' if t[3] & 1 else 'par'}, {names.get(t[3] >> 4, t[3] >> 4)}, at {ms(t[0]):.0f})" for t in sorted(tasks, key=lambda t: -t[1])[:5]))
if "--timeline" in a:
    for i, t in enumerate(turns):
        p = per[i]
        print(f"  {'G' if t[2] == 1 else 'D'} at {ms(t[0]):9.2f} wall {ms(t[1]):8.3f} rows {t[3]:3d} tasks {p['n']:6d} work {ms(sum(p['work'])):8.3f} busiest {ms(max(p['work'])):8.3f} longest {ms(p['longest']):8.3f}")
