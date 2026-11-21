#!/usr/bin/env python3
"""apply_rep_hook.py SRC_BEND2 DST_BEND2 HOOK: a scratch copy of bend2/ with
the hook appended to comp.ts; main.ts runs it over a list of files when
REP_LIST is set: REP_LIST=list.txt REP_OUT=x.jsonl bun DST/main.ts x"""
import shutil, sys
src, dst, hook = sys.argv[1:4]
shutil.rmtree(dst, ignore_errors=True)
shutil.copytree(src, dst)
open(f"{dst}/comp.ts", "a").write(open(hook).read())
m = open(f"{dst}/main.ts").read()
old = "if (import.meta.main) {"
assert m.count(old) == 1
m = m.replace(old, '''async function rep_list(): Promise<void> {
  const out = process.env.REP_OUT!;
  const base = await book_read(BASE);
  const names = new Set(Object.keys(base.tlds));
  if (process.env.REP_BASE) Comp.rep_count(base, "BASE", out, null);
  for (const f of fs.readFileSync(process.env.REP_LIST!, "utf8").split("\\n")) {
    if (f.trim() === "") continue;
    try {
      const own = /^(?:[\\t\\r ]*(?:#[^\\n]*)?\\n)*[\\t ]*import Base\\s/
        .test(fs.readFileSync(f, "utf8"));
      const book = await book_read(f, own ? base : undefined);
      Comp.rep_count(book, f, out, own ? names : null);
    } catch (e) {
      fs.appendFileSync(out, JSON.stringify({ file: f, kind: "fail",
        msg: String(book_err(e)).slice(0, 200) }) + "\\n");
    }
  }
}

async function rep_emit(): Promise<void> {
  const out = process.env.REP_EMIT!;
  const base = await book_read(BASE);
  for (const f of fs.readFileSync(process.env.REP_LIST!, "utf8").split("\\n")) {
    if (f.trim() === "") continue;
    let h = "";
    try {
      const own = /^(?:[\\t\\r ]*(?:#[^\\n]*)?\\n)*[\\t ]*import Base\\s/
        .test(fs.readFileSync(f, "utf8"));
      const book = await book_read(f, own ? base : undefined);
      h = String(Bun.hash(process.env.REP_JS ? Comp.js_book(book) : Comp.compile_book(book)));
    } catch (e) {
      h = "fail";
    }
    fs.appendFileSync(out, f + " " + h + "\\n");
  }
}

if (import.meta.main && process.env.REP_EMIT) {
  await rep_emit();
} else if (import.meta.main && process.env.REP_LIST) {
  await rep_list();
} else if (import.meta.main) {''')
open(f"{dst}/main.ts", "w").write(m)
