
// Survey hook (scratch; appended to a copy of comp.ts). survey(book) runs
// file_book as compile_book does, then counts, over the defs main reaches,
// where candidate general rewrites would fire. One JSON object per program.

type SvDef = { k: Name; rec: boolean; flat: boolean; depth: number;
  size: number; scc: number };

export function survey(book: Bend.Book): any {
  FL = file_new(main_pure(book), false);
  file_book(["main", ...RUNTIME_ADTS]);
  const defs = done_defs().map(([k]) => k).filter((k) => fun_of(k).h);
  const callees = new Map<Name, Set<Name>>();
  for (const d of defs) {
    const out = new Set<Name>();
    term_any(fun_of(d).h!, (s) => {
      if (s.$ === "Ref" && done_live(tld_of(s.k)) && !intr_of(s.k)) {
        out.add(s.k);
      }
      return false;
    });
    callees.set(d, out);
  }
  // Tarjan SCCs
  const idx = new Map<Name, number>(), low = new Map<Name, number>();
  const on = new Set<Name>(), st: Name[] = [], sccOf = new Map<Name, number>();
  const sccs: Name[][] = [];
  let n = 0;
  const visit = (v: Name) => {
    idx.set(v, n); low.set(v, n); n++; st.push(v); on.add(v);
    for (const w of callees.get(v) ?? []) {
      if (!callees.has(w)) continue;
      if (!idx.has(w)) { visit(w); low.set(v, Math.min(low.get(v)!, low.get(w)!)); }
      else if (on.has(w)) low.set(v, Math.min(low.get(v)!, idx.get(w)!));
    }
    if (low.get(v) === idx.get(v)) {
      const c: Name[] = [];
      let w: Name;
      do { w = st.pop()!; on.delete(w); c.push(w); sccOf.set(w, sccs.length); } while (w !== v);
      sccs.push(c);
    }
  };
  defs.forEach((d) => idx.has(d) || visit(d));
  const recS = sccs.map((c) => c.length > 1 || callees.get(c[0])!.has(c[0]));
  // depth: recursive SCCs entered along the deepest path from main (sccs come
  // out in reverse topological order)
  const dep = sccs.map(() => -1);
  const m0 = sccOf.get("main");
  if (m0 !== undefined) dep[m0] = Number(recS[m0]);
  for (let i = sccs.length - 1; i >= 0; i--) {
    if (dep[i] < 0) continue;
    for (const v of sccs[i]) for (const w of callees.get(v)!) {
      const j = sccOf.get(w);
      if (j !== undefined && j !== i) dep[j] = Math.max(dep[j], dep[i] + Number(recS[j]));
    }
  }
  const size = (t: HTerm): number => 1 + term_kids(term_force(t)).reduce((a, x) => a + size(x), 0);
  const info = new Map<Name, SvDef>();
  for (const d of defs) {
    const i = sccOf.get(d)!;
    info.set(d, { k: d, rec: recS[i], flat: flat_of(d), depth: dep[i], size: size(fun_of(d).h!), scc: sccs[i].length });
  }
  const maxd = Math.max(0, ...[...info.values()].map((x) => x.depth));
  const sites: any[] = [];
  const add = (kind: string, d: Name, extra: any = {}) =>
    sites.push({ kind, d, depth: info.get(d)!.depth, ...extra });
  // free variables of a term (var indices), binders removed
  const fvs = (t: HTerm, acc = new Set<number>(), bound = new Set<number>()): Set<number> => {
    const s = term_force(t);
    if (s.$ === "Var") { if (!bound.has(s.i)) acc.add(s.i); return acc; }
    if (s.$ === "Lam" || s.$ === "Let") term_open(s).ps.forEach((p) => bound.add(p.i));
    term_kids(s).forEach((x) => fvs(x, acc, bound));
    return acc;
  };
  const isOp = (k: Name | null) => !!k && !!intr_of(k);
  const chk = (k: string) => /^Nat\.(add|mul|sub|pow)|\.(div|mod)$/.test(k);
  // a pure expression: vars, constants, intrinsic ops (no Array), flat calls
  const pureKind = (t: HTerm): string | null => {
    const s = term_strip(t);
    if (s.$ === "Var" || term_const(s)) return "";
    const m = term_spine(s);
    if (s.$ === "Ctr") {
      const ks = ctr_flds(s).map(pureKind);
      return ks.some((x) => x === null) ? null : ["ctr", ...ks].filter(Boolean).join("+");
    }
    if (s.$ !== "App" && s.$ !== "Ref") return null;
    if (m.t.$ !== "Ref") return null;
    const k = m.t.k;
    if (/^Array\./.test(k)) return null;
    const ks = m.args.map(pureKind);
    if (ks.some((x) => x === null)) return null;
    const me = isOp(k) ? (chk(k) ? "chk" : "op") : m.k !== null && flat_call(s) ? "flat"
      : m.k !== null ? "far" : null;
    if (me === null) return null;
    return [...new Set([me, ...ks.flatMap((x) => x.split("+")).filter(Boolean)])].sort().join("+");
  };
  // leaves of a def: expressions after its parameters and matches
  const leaves = (d: Name): [HTerm, number[]][] => {
    const f = fun_of(d);
    const out: [HTerm, number[]][] = [];
    const tree = (t: HTerm, left: number[], pv: number[]): void => {
      const s = Bend.term_strip(t);
      if (left.length === 0) out.push([s, pv]);
      else if (s.$ === "Lam") {
        const o = term_open(s);
        tree(o.b, left.slice(1), pv.map((p, j) => j === left[0] ? o.ps[0].i : p));
      } else if (s.$ === "Mat") {
        tree(s.h, [...Array(FL.book.ctrs[s.k].n).fill(-1), ...left.slice(1)], pv);
        tree(s.m, left, pv);
      } else if (s.$ !== "Efq") out.push([s, pv]);
    };
    tree(f.h!, [...Array(f.n).keys()], Array(f.n).fill(-2));
    return out;
  };
  for (const d of defs) {
    const f = fun_of(d);
    const L = leaves(d);
    // 1. closures: a Lam or match in expression position
    const clo = (t: HTerm, ctx: string, tail: boolean): void => {
      const s = term_force(t);
      if (s.$ === "Ann") return clo(s.x, ctx, tail);
      if (s.$ === "Lam" || s.$ === "Mat") {
        add("clo", d, { ctx });
        const b = s.$ === "Lam" ? term_open(s).b : null;
        if (b) clo(b, "body", false);
        else term_kids(s).forEach((x) => clo(x, "body", false));
        return;
      }
      if (s.$ === "App") {
        const m = term_spine(s);
        if (m.k === CLO_APPLY) add("apply", d, { tail });
        const cal = m.k && m.k !== CLO_APPLY ? m.k : null;
        const ci = cal ? info.get(cal) : undefined;
        m.args.forEach((a, j) => {
          const x = term_strip(a);
          if ((x.$ === "Lam" || x.$ === "Mat") && cal) {
            // how the callee uses that parameter
            add("lamarg", d, { callee: cal, crec: ci?.rec ?? null, cflat: ci?.flat ?? null,
              csize: ci?.size ?? null, cdepth: ci?.depth ?? null, tail });
          }
          clo(a, cal ? "arg" : "arg?", false);
        });
        clo(m.h, "head", false);
        return;
      }
      if (s.$ === "Let") {
        const o = term_open(s);
        s.v.forEach((v) => clo(v, "let", false));
        return clo(o.b, ctx, tail);
      }
      term_kids(s).forEach((x) => clo(x, s.$ === "Ctr" ? "ctr" : "sub", false));
    };
    L.forEach(([l]) => clo(l, "tail", true));
    // 2a. sink: frame pushes and what could be recomputed after them
    for (const [l] of L) {
      let a: HTerm;
      try { a = anf(l, null); } catch { continue; }
      const pures: { p: Of<"Var">; kind: string; ops: number[]; u32: boolean }[] = [];
      const walk = (t: HTerm): void => {
        const s = term_strip(t);
        if (s.$ !== "Let") return;
        const o = term_open(s);
        if (o.ps.length === 1) {
          const v = s.v[0];
          const m = term_spine(term_strip(v));
          const push = m.k !== null && (m.k === CLO_APPLY || !flat_call(term_strip(v)));
          if (push) {
            const live = (p: Of<"Var">) => rest_use([o.b], p) > 0;
            let words = 0, sink = 0, s2217 = 0, kinds: string[] = [];
            const usedByCall = fvs(v);
            for (const q of pures) {
              if (!live(q.p) || usedByCall.has(q.p.i)) continue;
              const opsLive = q.ops.every((i) => live({ i } as any));
              if (opsLive) { sink++; kinds.push(q.kind); if (q.u32) s2217++; }
            }
            add("push", d, { sink, s2217, kinds, far: m.k });
          } else {
            const k = pureKind(v);
            if (k !== null && k !== "" && !k.includes("far")) {
              const ops = [...fvs(v)];
              const u32 = (() => {
                let ok = true;
                const go = (x: HTerm): void => {
                  const y = term_strip(x);
                  const g = term_spine(y);
                  if (y.$ === "Var" || term_const(y)) return;
                  if (g.t.$ === "Ref" && g.t.k.startsWith("U32.") && intr_of(g.t.k)) g.args.forEach(go);
                  else ok = false;
                };
                go(v);
                return ok;
              })();
              pures.push({ p: o.ps[0], kind: k, ops, u32 });
            }
          }
        }
        walk(o.b);
      };
      walk(a);
    }
    // 2b. float-out: invariant subterms of a self-recursive def
    if (info.get(d)!.rec && info.get(d)!.scc === 1) {
      const fixed = Array(f.n).fill(true);
      let calls = 0;
      for (const [l, pv] of L) {
        term_any(l, (s) => {
          const m = term_spine(s);
          if (s.$ === "App" && m.t.$ === "Ref" && m.t.k === d && m.all.length === f.n) {
            calls++;
            m.all.forEach((x, j) => {
              const v = Bend.term_strip(x);
              fixed[j] &&= v.$ === "Var" && v.i === pv[j];
            });
          }
          return false;
        });
      }
      if (calls > 0) {
        for (const [l, pv] of L) {
          const fx = new Set(pv.filter((p, j) => p >= 0 && fixed[j]));
          const inv = (t: HTerm): void => {
            const s = term_force(t);
            const st = term_strip(s);
            const m = term_spine(st);
            if ((st.$ === "App" || st.$ === "Ref") && m.t.$ === "Ref" && m.t.k !== d
              && m.k !== CLO_APPLY && !term_const(st)) {
              const vs = fvs(st);
              const k = pureKind(st);
              if (vs.size > 0 && [...vs].every((i) => fx.has(i)) && k !== null) {
                add("inv", d, { ek: k, dflat: info.get(d)!.flat, call: m.t.k });
                return;
              }
            }
            term_kids(s).forEach(inv);
          };
          inv(l);
        }
      }
    }
    // 2c. CSE: a pure call or op twice in one leaf
    for (const [l] of L) {
      const seen = new Map<string, number>();
      const kinds = new Map<string, string>();
      const cse = (t: HTerm, dd: number): void => {
        if (term_force(t).$ === "Ann") return cse((term_force(t) as any).x, dd);
        const s = term_strip(t);
        const m = term_spine(s);
        if ((s.$ === "App") && m.t.$ === "Ref" && m.k !== CLO_APPLY && !term_const(s)) {
          const k = pureKind(s);
          if (k !== null && k !== "" && fvs(s).size > 0) {
            let key: string;
            try { key = JSON.stringify(Bend.term_lower(s, 1 << 20), (j, v) => j === "s" ? undefined : v?.$ === "Ann" ? Bend.term_strip(v) : v); } catch { key = ""; }
            if (key) { seen.set(key, (seen.get(key) ?? 0) + 1); kinds.set(key, k); }
          }
        }
        term_kids(term_force(t)).forEach((x) => cse(x, dd));
      };
      cse(l, 0);
      for (const [key, c] of seen) if (c >= 2) add("cse", d, { ek: kinds.get(key), n: c });
    }
    // 3. tail contexts of self calls: constructor (TRMC) or operator
    if (info.get(d)!.rec) {
      const scc = new Set(sccs[sccOf.get(d)!]);
      for (const [l] of L) {
        const tl = (t: HTerm): void => {
          const s = term_strip(t);
          if (s.$ === "Let") return tl(term_open(s).b);
          const m = term_spine(s);
          const selfIn = (x: HTerm) => term_any(x, (y) => { const g = term_spine(y); return y.$ === "App" && !!g.k && scc.has(g.k); });
          if (s.$ === "Ctr" && ctr_flds(s).some(selfIn)) {
            const lay = lay_of(ty_ann(t));
            add("tmc", d, { ctr: s.k, n: ctr_flds(s).filter(selfIn).length });
          } else if ((s.$ === "App") && m.t.$ === "Ref" && isOp(m.t.k) && m.args.some(selfIn)) {
            add("tmo", d, { op: m.t.k, n: m.args.filter(selfIn).length });
          } else if (s.$ === "App" && m.k && !scc.has(m.k) && m.args.some(selfIn)) {
            add("tmf", d, { f: m.k });
          }
        };
        tl(l);
      }
    }
  }

  // SCCs: size, depth, whether every call inside the SCC is a tail call
  const loops = sccs.map((c, i) => {
    if (!recS[i]) return null;
    const set = new Set(c);
    let tailOnly = true;
    c.forEach((d) => term_any(fun_of(d).h!, (s, tail) => {
      const g = term_spine(s);
      if (s.$ === "App" && g.k && set.has(g.k) && !tail) tailOnly = false;
      return false;
    }));
    return [c.slice(0, 4), c.length, dep[i], tailOnly ? 1 : 0];
  }).filter(Boolean);
  let units = 0;
  try { units = c_units().length; } catch (e) { units = -1; }
  const hotc = new Set([...FL.facts].filter((f) => f.startsWith("ctr ")).map((f) => f.slice(4)));
  sites.forEach((s) => { if (s.kind === "tmc") s.hot = hotc.has(s.ctr); });
  const packs = Object.keys(FL.book.ctrs).filter((k) => { try { return FL.nodes.has(k) && node_pack(k) !== null; } catch { return false; } });
  return { loops, units, hotc: [...hotc], packs, maxd, defs: [...info.values()].map((x) => [x.k, x.rec ? 1 : 0, x.flat ? 1 : 0, x.depth, x.size]), sites };
}
