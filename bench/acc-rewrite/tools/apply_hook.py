#!/usr/bin/env python3
"""apply_hook.py SRC_BEND2 DST_BEND2: a scratch copy of bend2/ with the
acc-count hook (hook/acc_hook.ts appended to comp.ts; main.ts runs it over a
list of files when ACC_LIST is set). Run: ACC_LIST=list.txt ACC_OUT=x.jsonl
bun DST/main.ts any.bend"""
import os, shutil, sys
src, dst = sys.argv[1:3]
here = os.path.dirname(os.path.abspath(__file__))
shutil.rmtree(dst, ignore_errors=True)
shutil.copytree(src, dst)
open(f"{dst}/comp.ts", "a").write(open(f"{here}/../hook/acc_hook.ts").read())
m = open(f"{dst}/main.ts").read()
old = "if (import.meta.main) {"
assert m.count(old) == 1
m = m.replace(old, '''async function acc_list(): Promise<void> {
  const out = process.env.ACC_OUT!;
  const base = await book_read(BASE);
  const names = new Set(Object.keys(base.tlds));
  Comp.acc_count(base, "BASE", out, null);
  for (const f of fs.readFileSync(process.env.ACC_LIST!, "utf8").split("\\n")) {
    if (f.trim() === "") {
      continue;
    }
    try {
      const own = /^(?:[\\t\\r ]*(?:#[^\\n]*)?\\n)*[\\t ]*import Base\\s/
        .test(fs.readFileSync(f, "utf8"));
      const book = await book_read(f, own ? base : undefined);
      Comp.acc_count(book, f, out, own ? names : null);
    } catch (e) {
      fs.appendFileSync(out, JSON.stringify({ file: f, kind: "fail",
        msg: String(book_err(e)).slice(0, 200) }) + "\\n");
    }
  }
}

if (import.meta.main && process.env.ACC_LIST) {
  await acc_list();
} else if (import.meta.main) {''')
open(f"{dst}/main.ts", "w").write(m)
