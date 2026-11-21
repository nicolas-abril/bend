
// Acc-count hook (bench/acc-rewrite)
// ==================================
//
// Appended to a scratch copy of bend2/comp.ts (tools/apply_hook.py); not part
// of the compiler. acc_count walks every runnable def of a checked book and
// appends JSON lines to `out`:
//
// - {kind:"mat"}: one per match chain (a Mat in the core). fam is the matched
//   type; scrut is "param" (the next parameter of the def), "field" (a field
//   of an enclosing arm: a nested pattern) or "applied" (a match on a
//   computed value). For every nullary constructor C0 and every constructor C
//   with fields, the arms are compared with C's fields replaced by
//   candidates, C0{} read as C{candidates} everywhere (the representation
//   change): "plain" (constants, no rewriting), "ident" (constants, then the
//   arithmetic identities and constant folding: x+0, 0+x, x-0, x*1, 1*x,
//   x*0, x|0, x^0, x&~0, x&0, inc of a literal, a U32 op on literals) and
//   "broad" (the identities, and fields may also be any variable in scope or
//   any later parameter: the Option-plus-default shape). Each lists the
//   tuples that work ("*" is an unused field). fuse lists, per field of each
//   constructor with fields, how the arm uses it: unused, add (only as an
//   operand of U32.add / Nat.add whose other operand reads a variable: added
//   into another value), assoc (the same for any associative, commutative
//   op: add, mul, or, xor, and, min, max), other.
// - {kind:"call2"}: one per call (a def, not an intrinsic) one of whose
//   arguments is itself a call to a def (a non-tail call whose result is
//   passed straight into another call). For the outer callee's parameter at
//   that position: how it is consumed on every path (pk: "lam" taken whole,
//   "mat" matched, "mixed"), and per field (or the word itself) the use
//   class as above, plus whether the inner callee can return a nullary
//   constructor (retc0).
// - {kind:"def"}, {kind:"adt"}, {kind:"reach"}: the defs, the types, and the
//   defs reachable from main.

const ACC_ADD = new Set(["U32.add", "Nat.add"]);
const ACC_ASSOC = new Set(["U32.add", "Nat.add", "U32.mul", "U32.or",
  "U32.xor", "U32.and", "Nat.mul", "Nat.min", "Nat.max", "Bool.or",
  "Bool.and", "Bool.xor"]);
const ACC_SKIP_FAM = new Set(["Nat", "U32", "F32", "Char", "String", "Array",
  "IO.OP", "Bool"]);
const ACC_MAXW = 0xFFFFFFFF;

type AccW = (o: Record<string, unknown>) => void;

function acc_unapp(t: HTerm): [HTerm, HTerm[]] {
  const xs: HTerm[] = [];
  let c = Bend.term_strip(t);
  while (c.$ === "App") {
    xs.unshift(c.x);
    c = Bend.term_strip(c.f);
  }
  return [c, xs];
}

function acc_u32(t: HTerm): number | null {
  const s = Bend.term_strip(t);
  return s.$ === "Lit" && s.k === "U32" ? Number(s.v) >>> 0 : null;
}

function acc_nat(t: HTerm): number | null {
  const s = Bend.term_strip(t);
  return s.$ === "Lit" && s.k === "Nat" ? Number(s.v)
    : s.$ === "Ctr" && s.k === "Zero" ? 0 : null;
}

// the head-normal form under the identities: an application of an
// arithmetic op that is the identity on one operand, or folds
function acc_norm(t: HTerm, ident: boolean, alias: Map<Name, HTerm>): HTerm {
  for (let i = 0; i < 64; i++) {
    const s = Bend.term_strip(t);
    if (s.$ === "Ctr" && alias.has(s.k) && s.x.length === 0) {
      return alias.get(s.k)!;
    }
    if (!ident || s.$ !== "App") {
      return s;
    }
    const [h, xs] = acc_unapp(s);
    if (h.$ !== "Ref") {
      return s;
    }
    const k = h.k;
    const un = k === "U32.inc" || k === "U32.not";
    const a = xs.length >= (un ? 1 : 2) ? acc_norm(xs[xs.length - (un ? 1 : 2)],
      ident, alias) : null;
    const b = !un && xs.length >= 2 ? acc_norm(xs[xs.length - 1], ident, alias)
      : null;
    const U = (v: number) => Bend.Lit("U32", v >>> 0) as HTerm;
    if (k === "U32.inc" && a) {
      const x = acc_u32(a);
      if (x !== null) {
        return U(x + 1);
      }
      return s;
    }
    if (!a || !b) {
      return s;
    }
    const x = acc_u32(a);
    const y = acc_u32(b);
    if (x !== null && y !== null) {
      const f: Record<string, (p: number, q: number) => number> = {
        "U32.add": (p, q) => p + q, "U32.sub": (p, q) => p - q,
        "U32.mul": (p, q) => Math.imul(p, q), "U32.or": (p, q) => p | q,
        "U32.xor": (p, q) => p ^ q, "U32.and": (p, q) => p & q,
      };
      if (f[k]) {
        return U(f[k](x, y));
      }
    }
    const nx = acc_nat(a);
    const ny = acc_nat(b);
    if (k === "U32.add" || k === "U32.or" || k === "U32.xor") {
      if (y === 0) { t = a; continue; }
      if (x === 0) { t = b; continue; }
    } else if (k === "U32.sub") {
      if (y === 0) { t = a; continue; }
    } else if (k === "U32.mul") {
      if (y === 1) { t = a; continue; }
      if (x === 1) { t = b; continue; }
      if (x === 0 || y === 0) { return U(0); }
    } else if (k === "U32.and") {
      if (y === ACC_MAXW) { t = a; continue; }
      if (x === ACC_MAXW) { t = b; continue; }
      if (x === 0 || y === 0) { return U(0); }
    } else if (k === "Nat.add") {
      if (ny === 0) { t = a; continue; }
      if (nx === 0) { t = b; continue; }
    } else if (k === "Nat.mul") {
      if (ny === 1) { t = a; continue; }
      if (nx === 1) { t = b; continue; }
    }
    return s;
  }
  return Bend.term_strip(t);
}

// equality of two terms, opening binders with shared variables, under the
// constructor alias and (if ident) the identities
function acc_eq(a: HTerm, b: HTerm, ident: boolean, alias: Map<Name, HTerm>,
  d = 1 << 28): boolean {
  const x = acc_norm(a, ident, alias);
  const y = acc_norm(b, ident, alias) as any;
  if (x === y) {
    return true;
  }
  if (x.$ !== y.$) {
    return false;
  }
  switch (x.$) {
    case "Var":
      return x.i === y.i && (x.i >= 0 || x === y);
    case "Ref":
      return x.k === y.k;
    case "Lit":
      return x.k === y.k && x.v === y.v;
    case "Lam": {
      const v = Bend.Var(x.k, d) as HTerm;
      return acc_eq(x.f(v), y.f(v), ident, alias, d + 1);
    }
    case "Let": {
      if (x.k.length !== y.k.length || !x.v.every((v: HTerm, i: number) =>
        acc_eq(v, y.v[i], ident, alias, d))) {
        return false;
      }
      const vs = x.k.map((k: Name, i: number) => Bend.Var(k, d + i) as HTerm);
      return acc_eq(x.f(vs), y.f(vs), ident, alias, d + x.k.length);
    }
    case "App":
      return acc_eq(x.f, y.f, ident, alias, d) && acc_eq(x.x, y.x, ident, alias, d);
    case "Ctr":
      return x.k === y.k && x.x.length === y.x.length
        && x.x.every((t: HTerm, i: number) => acc_eq(t, y.x[i], ident, alias, d));
    case "Mat":
      return x.k === y.k && acc_eq(x.h, y.h, ident, alias, d)
        && acc_eq(x.m, y.m, ident, alias, d);
    case "Rwt":
      return acc_eq(x.f, y.f, ident, alias, d);
    case "Efq":
      return true;
    default:
      return term_same(x, y, d);
  }
}

function acc_lams(t: HTerm): number {
  let n = 0;
  for (let s = Bend.term_strip(t); s.$ === "Lam"; n++) {
    s = Bend.term_strip(term_open(s).b);
  }
  return n;
}

function acc_apply(t: HTerm, xs: HTerm[]): HTerm {
  return xs.reduce((f, x) => Bend.term_apply(f, x), t);
}

// how t uses variable p: "unused", "add", "assoc", "other"
function acc_use(t: HTerm, p: HTerm): string {
  const pi = (p as Of<"Var">).i;
  let add = true;
  let assoc = true;
  let seen = false;
  const isp = (x: HTerm) => {
    const s = Bend.term_strip(x);
    return s.$ === "Var" && s.i === pi;
  };
  const go = (x: HTerm): void => {
    const s = Bend.term_force(x);
    if (s.$ === "Var") {
      if (s.i === pi) {
        seen = true;
        add = false;
        assoc = false;
      }
      return;
    }
    if (s.$ === "App") {
      const [h, xs] = acc_unapp(s);
      if (h.$ === "Ref" && (ACC_ASSOC.has(h.k) || h.k === "U32.inc")) {
        const ops = h.k === "U32.inc" ? xs.slice(-1) : xs.slice(-2);
        const rest = h.k === "U32.inc" ? xs.slice(0, -1) : xs.slice(0, -2);
        rest.forEach(go);
        for (const o of ops) {
          if (isp(o)) {
            seen = true;
            // into another value: the other operand reads some variable
            const other = ops.find((q) => q !== o);
            const into = other !== undefined && !isp(other)
              && acc_vars(other).size > 0;
            if (!ACC_ADD.has(h.k) || !into) {
              add = false;
            }
            if (!into) {
              assoc = false;
            }
          } else {
            go(o);
          }
        }
        return;
      }
      go(s.f);
      go(s.x);
      return;
    }
    if (s.$ === "Lam" || s.$ === "Let") {
      const o = term_open(s);
      if (s.$ === "Let") {
        s.v.forEach(go);
      }
      go(o.b);
      return;
    }
    if (s.$ === "Ann") {
      go(s.x);
    } else if (s.$ === "Ctr") {
      s.x.forEach(go);
    } else if (s.$ === "Mat") {
      go(s.h);
      go(s.m);
    } else if (s.$ === "Rwt") {
      go(s.f);
    }
  };
  go(t);
  return !seen ? "unused" : add ? "add" : assoc ? "assoc" : "other";
}

function acc_fam(k: Name): Name {
  return FL.book.ctrs[k]?.f ?? k;
}

function acc_adt(fam: Name): Bend.Ctrs | null {
  const t = FL.book.tlds[fam];
  return t?.$ === "ADT" ? t.c : null;
}

function acc_vars(t: HTerm, out = new Set<number>()): Set<number> {
  const s = Bend.term_force(t);
  if (s.$ === "Var") {
    out.add(s.i);
  }
  term_kids_raw(s).forEach((x) => acc_vars(x, out));
  return out;
}

function term_kids_raw(s: HTerm): HTerm[] {
  switch (s.$) {
    case "Ann": return [s.x];
    case "Lam": return [term_open(s).b];
    case "Let": return [...s.v, term_open(s).b];
    case "App": return [s.f, s.x];
    case "Ctr": return s.x;
    case "Mat": return [s.h, s.m];
    case "Rwt": return [s.f];
    default: return [];
  }
}

// candidates for a field: constants (and, broad, variables)
function acc_consts(ctr: Bend.Ctr, i: number): [string, HTerm][] {
  const out: [string, HTerm][] = [["0", Bend.Lit("U32", 0) as HTerm],
    ["1", Bend.Lit("U32", 1) as HTerm], ["~0", Bend.Lit("U32", ACC_MAXW) as HTerm],
    ["0n", Bend.Lit("Nat", 0) as HTerm], ["False", Bend.Ctr("False", []) as HTerm],
    ["True", Bend.Ctr("True", []) as HTerm]];
  try {
    const doms = Bend.tele_unbind(FL.book, ctr.T).doms;
    const A = doms[doms.length - ctr.n + i]?.[2];
    const adt = A ? ty_adt(A) : null;
    const cs = adt ? acc_adt(adt.k) : null;
    for (const c of cs ?? []) {
      if (c.n === 0 && c.k !== "False" && c.k !== "True") {
        out.push([c.k, Bend.Ctr(c.k, []) as HTerm]);
      }
    }
  } catch {
    // a field type we cannot read: the word constants only
  }
  return out;
}

function acc_mat(x: Of<"Mat">, scrut: string, scope: HTerm[], def: Name,
  w: AccW): void {
  const { arms, end } = mat_arms(x);
  const fam = acc_fam(arms[0][0]);
  const cs = acc_adt(fam);
  const rec: Record<string, unknown> = { kind: "mat", def, fam, scrut,
    ctrs: cs?.map((c) => c.k + "/" + c.n) ?? null };
  if (!cs || ACC_SKIP_FAM.has(fam) || fam === "Nat") {
    w({ ...rec, skip: true });
    return;
  }
  const exp = new Map(arms);
  const dflt = Bend.term_strip(end).$ === "Efq" ? null : end;
  rec.dflt = dflt !== null;
  const arm = (k: Name): ((vs: HTerm[]) => HTerm) | null =>
    exp.has(k) ? (vs) => acc_apply(exp.get(k)!, vs)
      : dflt ? (vs) => Bend.term_apply(dflt, Bend.Ctr(k, vs) as HTerm) : null;
  const nul = cs.filter((c) => c.n === 0);
  const ful = cs.filter((c) => c.n > 0);
  // field uses per constructor with fields
  const fuse: Record<string, string[]> = {};
  for (const c of ful) {
    const a = arm(c.k);
    if (!a) {
      continue;
    }
    const ps = [...Array(c.n)].map((_, i) => probe("f" + i));
    const b = a(ps);
    fuse[c.k] = ps.map((p) => acc_use(b, p));
  }
  rec.fuse = fuse;
  const res: Record<string, unknown>[] = [];
  for (const c0 of nul) {
    const a0 = arm(c0.k);
    if (!a0) {
      continue;
    }
    for (const c of ful) {
      const ac = arm(c.k);
      if (!ac) {
        continue;
      }
      const used = fuse[c.k].map((u) => u !== "unused");
      const m = Math.min(acc_lams(a0([])), acc_lams(ac([...Array(c.n)].map(
        () => Bend.Lit("U32", 0) as HTerm))));
      const rs = [...Array(m)].map((_, i) => probe("r" + i));
      const b0 = acc_apply(a0([]), rs);
      const tryall = (cand: (i: number) => [string, HTerm][], ident: boolean,
        cap: number): string[][] => {
        const lists = [...Array(c.n)].map((_, i) => used[i] ? cand(i)
          : [["*", Bend.Lit("U32", 0) as HTerm] as [string, HTerm]]);
        const found: string[][] = [];
        let tries = 0;
        const rec2 = (i: number, acc: [string, HTerm][]) => {
          if (found.length >= cap || tries > 4096) {
            return;
          }
          if (i === c.n) {
            tries++;
            const vals = acc.map(([, v]) => v);
            const alias = new Map([[c0.k, Bend.Ctr(c.k, vals) as HTerm]]);
            const bc = acc_apply(ac(vals), rs);
            if (acc_eq(b0, bc, ident, alias)) {
              found.push(acc.map(([n]) => n));
            }
            return;
          }
          for (const p of lists[i]) {
            rec2(i + 1, [...acc, p]);
          }
        };
        rec2(0, []);
        return found;
      };
      const consts = (i: number) => acc_consts(c, i);
      const plain = tryall(consts, false, 16);
      const ident = tryall(consts, true, 16);
      const broad = ident.length ? ident : tryall((i) => [...consts(i),
        ...scope.map((v, j) => ["s" + j + ":" + (v as Of<"Var">).k, v] as [string, HTerm]),
        ...rs.map((v, j) => ["r" + j, v] as [string, HTerm])], true, 4);
      res.push({ c0: c0.k, c: c.k, n: c.n, plain, ident, broad });
    }
  }
  rec.res = res;
  w(rec);
}

// the binders a def's parameter j is taken by, on every path: a Lam (the
// value whole) or a Mat (matched); `pend` field slots come first
function acc_at(t: HTerm, idx: number, pend: number, j: number,
  out: HTerm[], depth = 0): void {
  const s = Bend.term_strip(t);
  if (depth > 400) {
    return;
  }
  if (s.$ === "Lam") {
    const o = term_open(s);
    if (pend > 0) {
      acc_at(o.b, idx, pend - 1, j, out, depth + 1);
    } else if (idx === j) {
      out.push(s);
    } else {
      acc_at(o.b, idx + 1, 0, j, out, depth + 1);
    }
  } else if (s.$ === "Mat") {
    if (pend === 0 && idx === j) {
      out.push(s);
      return;
    }
    const { arms, end } = mat_arms(s);
    for (const [k, h] of arms) {
      const n = FL.book.ctrs[k]?.n ?? 0;
      acc_at(h, pend > 0 ? idx : idx + 1, (pend > 0 ? pend - 1 : 0) + n, j,
        out, depth + 1);
    }
    if (Bend.term_strip(end).$ !== "Efq") {
      acc_at(end, idx, pend, j, out, depth + 1);
    }
  }
}

function acc_param(g: Name, j: number): Record<string, unknown> {
  const h = fun_of(g).h;
  if (!h) {
    return { pk: "none" };
  }
  const at: HTerm[] = [];
  acc_at(h, 0, 0, j, at);
  if (!at.length) {
    return { pk: "none" };
  }
  const kinds = new Set(at.map((t) => t.$));
  const uses: string[] = [];
  let fam: string | null = null;
  for (const t of at) {
    if (t.$ === "Lam") {
      const o = term_open(t as Of<"Lam">);
      uses.push(acc_use(o.b, o.ps[0]));
    } else {
      const { arms, end } = mat_arms(t);
      fam = acc_fam(arms[0][0]);
      for (const [k, a] of arms) {
        const n = FL.book.ctrs[k]?.n ?? 0;
        const ps = [...Array(n)].map((_, i) => probe("f" + i));
        const b = acc_apply(a, ps);
        ps.forEach((p) => uses.push(acc_use(b, p)));
      }
      if (Bend.term_strip(end).$ !== "Efq") {
        uses.push("other");
      }
    }
  }
  const rank = ["unused", "add", "assoc", "other"];
  const worst = uses.reduce((a, b) => rank.indexOf(b) > rank.indexOf(a) ? b : a,
    "unused");
  return { pk: kinds.size > 1 ? "mixed" : kinds.has("Lam") ? "lam" : "mat",
    paths: at.length, fam, use: worst };
}

// the constructors a def returns in tail position (its own tail calls aside)
function acc_rets(g: Name): Set<Name> {
  const out = new Set<Name>();
  const h = fun_of(g).h;
  const go = (t: HTerm, d: number): void => {
    const s = Bend.term_strip(t);
    if (d > 400) {
      return;
    }
    if (s.$ === "Lam" || s.$ === "Let") {
      go(term_open(s).b, d + 1);
    } else if (s.$ === "Mat") {
      mat_arms(s).arms.forEach(([, a]) => go(a, d + 1));
      const e = mat_arms(s).end;
      if (Bend.term_strip(e).$ !== "Efq") {
        go(e, d + 1);
      }
    } else if (s.$ === "Ctr") {
      out.add(s.k);
    } else if (s.$ === "Rwt") {
      go(s.f, d + 1);
    } else if (s.$ === "App") {
      const [f] = acc_unapp(s);
      if (f.$ === "Mat") {
        go(f, d + 1);
      } else if (f.$ === "Ref" && f.k !== g) {
        out.add("call:" + f.k);
      }
    }
  };
  if (h) {
    go(h, 0);
  }
  return out;
}

function acc_is_call(t: HTerm): Name | null {
  const [h] = acc_unapp(t);
  if (h.$ !== "Ref" || intr_of(h.k)) {
    return null;
  }
  const tld = FL.book.tlds[h.k];
  return fun_runs(tld) ? h.k : null;
}

function acc_def(def: Name, w: AccW): void {
  const h = fun_of(def).h;
  if (!h) {
    return;
  }
  const go = (t: HTerm, scope: HTerm[], pend: number, top: boolean): void => {
    const s = Bend.term_force(t);
    switch (s.$) {
      case "Ann":
        return go(s.x, scope, pend, top);
      case "Lam": {
        const o = term_open(s);
        return go(o.b, [...scope, o.ps[0]], pend > 0 ? pend - 1 : 0, top);
      }
      case "Let": {
        const o = term_open(s);
        s.v.forEach((v) => go(v, scope, 0, false));
        return go(o.b, [...scope, ...o.ps], 0, false);
      }
      case "Mat": {
        acc_mat(s, pend > 0 ? "field" : top ? "param" : "lam", scope, def, w);
        const { arms, end } = mat_arms(s);
        for (const [k, a] of arms) {
          const n = FL.book.ctrs[k]?.n ?? 0;
          go(a, scope, (pend > 0 ? pend - 1 : 0) + n, top);
        }
        if (Bend.term_strip(end).$ !== "Efq") {
          go(end, scope, pend, top);
        }
        return;
      }
      case "App": {
        const [f, xs] = acc_unapp(s);
        if (f.$ === "Mat") {
          acc_mat(f, "applied", scope, def, w);
          const { arms, end } = mat_arms(f);
          arms.forEach(([, a]) => go(a, scope, 0, false));
          if (Bend.term_strip(end).$ !== "Efq") {
            go(end, scope, 0, false);
          }
        } else {
          go(f, scope, 0, false);
        }
        const g = acc_is_call(s);
        if (g !== null) {
          xs.forEach((x, j) => {
            const g2 = acc_is_call(x);
            if (g2 !== null) {
              const p = acc_param(g, j);
              const rets = acc_rets(g2);
              const c0s = [...rets].filter((k) => FL.book.ctrs[k]?.n === 0);
              w({ kind: "call2", def, outer: g, inner: g2, pos: j, ...p,
                retc0: c0s, nargs: xs.length });
            }
          });
        }
        xs.forEach((x) => go(x, scope, 0, false));
        return;
      }
      case "Ctr":
        s.x.forEach((x) => go(x, scope, 0, false));
        return;
      case "Rwt":
        return go(s.f, scope, pend, top);
      default:
        return;
    }
  };
  go(h, [], 0, true);
}

function acc_refs(t: HTerm, out: Set<Name>, d = 0): void {
  const s = Bend.term_force(t);
  if (d > 2000) {
    return;
  }
  if (s.$ === "Ref") {
    out.add(s.k);
  }
  if (s.$ === "Ctr") {
    out.add("ctr:" + s.k);
  }
  term_kids_raw(s).forEach((x) => acc_refs(x, out, d + 1));
}

export function acc_count(book: Bend.Book, file: string, out: string,
  skip: Set<Name> | null): void {
  FL = file_new(book, false);
  file_owned();
  const lines: string[] = [];
  const w: AccW = (o) => lines.push(JSON.stringify({ file, ...o }));
  for (const [k, tld] of Object.entries(book.tlds)) {
    if (tld.$ === "ADT" && !skip?.has(k)) {
      w({ kind: "adt", fam: k, ctrs: tld.c.map((c) => c.k + "/" + c.n) });
    }
  }
  for (const [k, tld] of Object.entries(book.tlds)) {
    if (skip?.has(k) || !done_live(tld) || def_foreign(tld)) {
      continue;
    }
    w({ kind: "def", def: k });
    try {
      acc_def(k, w);
    } catch (e) {
      w({ kind: "err", def: k, msg: String((e as Error)?.stack ?? e).slice(0, 600) });
    }
  }
  if (book.tlds.main) {
    const seen = new Set<Name>(["main"]);
    const todo = ["main"];
    while (todo.length) {
      const k = todo.pop()!;
      const h = fun_runs(book.tlds[k]) ? fun_of(k).h : null;
      const rs = new Set<Name>();
      if (h) {
        acc_refs(h, rs);
      }
      for (const r of rs) {
        if (!seen.has(r) && !r.startsWith("ctr:") && book.tlds[r]) {
          seen.add(r);
          todo.push(r);
        }
      }
    }
    w({ kind: "reach", defs: [...seen] });
  }
  fs.appendFileSync(out, lines.join("\n") + (lines.length ? "\n" : ""));
}
