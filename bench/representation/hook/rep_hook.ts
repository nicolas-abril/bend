
// Representation-count hook (bench/representation)
// ================================================
//
// Appended to a scratch copy of bend2/comp.ts (tools/apply_rep_hook.py); not
// part of the compiler. rep_count walks a checked book and appends JSON lines:
// - {kind:"ctr"}: per constructor of a declared type (Base's only for the
//   file BASE): its type is recursive (a heap node) or not (words), its
//   words, node_pack's slots (null: no class drop), the class before/after,
//   whether foreign C fixes its layout, the bits per word.
// - {kind:"adt"}: per type: constructors, recursive, one-constructor wrapper,
//   list-like (one nullary, one with a single self field), record packing
//   (non-recursive: words, and words if its tag and w32 words shared 56-bit
//   words).
// - {kind:"def"}: per def: closures built (a live lambda or lambda-match off
//   the def's head), partial applications (call_eta), Clo~apply spines.

function rep_closures(k: Name): { clo: number; eta: number; app: number } {
  const r = { clo: 0, eta: 0, app: 0 };
  const go = (t: HTerm, head: boolean, callee = false): void => {
    const s = term_force(t);
    if ((s.$ === "Lam" || s.$ === "Mat") && !head) {
      let live = s.$ === "Mat";
      try {
        const T = ty_ann(t);
        live ||= T === null || ty_all(T).q.$ !== "None";
      } catch {
        live = true;
      }
      r.clo += Number(live);
      head = true;
    }
    if ((s.$ === "App" || s.$ === "Ref") && !callee) {
      const m = term_spine(s);
      if (m.k === CLO_APPLY) r.app++;
      if (m.t.$ === "Ref" && call_eta(s) !== null) r.eta++;
    }
    const kids = term_kids(s);
    kids.forEach((x, i) => go(x, (s.$ === "Lam" || s.$ === "Mat" || s.$ === "Ann"
      || (s.$ === "Let" && i === kids.length - 1)) ? head : false,
      (s.$ === "App" && i === 0) || (s.$ === "Ann" && callee)));
  };
  go(fun_of(k).h!, true);
  return r;
}

export function rep_count(book: Bend.Book, file: string, out: string,
  skip: Set<Name> | null): void {
  FL = file_new(book, false);
  file_owned();
  const lines: string[] = [];
  const w = (o: Record<string, unknown>) => lines.push(JSON.stringify({ file, ...o }));
  let reach: Set<Name> | null = null;
  try {
    if (book.tlds.main) {
      file_book(["main", ...RUNTIME_ADTS]);
      reach = new Set(FL.srcs.keys());
    }
  } catch (e) {
    w({ kind: "err", where: "file_book", msg: String(e).slice(0, 300) });
  }
  for (const [k, tld] of Object.entries(book.tlds)) {
    if (tld.$ !== "ADT" || skip?.has(k) || OWNED.includes(k)) continue;
    try {
      const rec = lay_of(Bend.ADT(k, [])) === BOX;
      const cs = tld.c.map((c) => ({ k: c.k, n: ctr_doms(c).length }));
      const self = (c: Bend.Ctr) => ctr_doms(c).filter((F) => ty_adt(F)?.k === k).length;
      const listy = tld.c.length === 2 && tld.c.some((c) => ctr_doms(c).length === 0)
        && tld.c.some((c) => self(c) === 1 && ctr_doms(c).length >= 2);
      let rw: number[] | null = null;
      if (!rec) {
        try {
          const lay = lay_of(Bend.ADT(k, []));
          const bs = lay_bits(lay);
          const used: number[] = [];
          for (const b of [...bs].sort((x, y) => y - x)) {
            if (b > 32) continue;
            const i = used.findIndex((u) => u + b <= 56);
            if (i < 0) used.push(b); else used[i] += b;
          }
          rw = [bs.length, bs.filter((b) => b > 32).length + used.length,
            bs.filter((b) => b < 32).length];
        } catch { rw = null; }
      }
      w({ kind: "adt", fam: k, rec, ctrs: cs, wrapper: tld.c.length === 1 && cs[0].n === 1,
        listy, rw, reached: reach ? reach.has(k) : null, fixed: FL.fixed.has(k) });
      if (rec) {
        for (const c of tld.c) {
          const lay = lay_node(c.k);
          const bs = ctr_doms(c).map(lay_of).flatMap(lay_bits);
          const pk = node_pack(c.k);
          const n = lay.ks.length;
          w({ kind: "ctr", fam: k, ctr: c.k, words: n, bits: bs,
            pack: pk ? pk.n : null, cls: cls_fit(n), cls2: pk ? cls_fit(pk.n) : null,
            small: bs.filter((b) => b < 32).length, w32: bs.filter((b) => b === 32).length,
            fixed: FL.fixed.has(k), reached: reach ? reach.has(k) : null });
        }
      }
    } catch (e) {
      w({ kind: "err", fam: k, msg: String((e as Error)?.stack ?? e).slice(0, 300) });
    }
  }
  for (const [k, tld] of Object.entries(book.tlds)) {
    if (skip?.has(k) || !done_live(tld) || def_foreign(tld)) continue;
    try {
      const r = rep_closures(k);
      if (r.clo || r.eta || r.app) {
        w({ kind: "def", def: k, ...r, reached: reach ? reach.has(k) : null });
      }
    } catch (e) {
      w({ kind: "err", def: k, msg: String((e as Error)?.stack ?? e).slice(0, 300) });
    }
  }
  fs.appendFileSync(out, lines.join("\n") + (lines.length ? "\n" : ""));
}
