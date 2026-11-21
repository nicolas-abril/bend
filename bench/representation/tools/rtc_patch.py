#!/usr/bin/env python3
"""rtc_patch.py SRC_BEND2 DST_BEND2: scratch compiler whose C counts, at run
time, the representation events: a record boxed into / read back from a heap
node, every heap node built per constructor, closures built per def, every
Clo~apply call per site, partial applications (call_eta) per callee, rfc_wrap.
Keys go to $REPC_KEYS (one per line, index = line number)."""
import shutil, sys
src, dst = sys.argv[1:3]
shutil.rmtree(dst, ignore_errors=True)
shutil.copytree(src, dst)
p = f"{dst}/comp.ts"
s = open(p).read()
def sub(old, new, n=1):
    global s
    assert s.count(old) == n, (old, s.count(old))
    s = s.replace(old, new)
s += '''
const REPK = new Map<string, number>();
function repc(sc: Scope, key: string): void {
  if (FL.js) return;
  let i = REPK.get(key);
  if (i === undefined) { i = REPK.size + 1; REPK.set(key, i); }
  file_push(sc, `REPC_INC(${i});`);
}
export function repc_keys(): string[] { return [...REPK.keys()]; }
'''
# boxing a record
sub('''function val_box(sc: Scope, v: Val): string {
  if (v.lay.arms === null) {
    return val_own(v)[0];
  }
  const arms = Object.keys(v.lay.arms);''', '''function val_box(sc: Scope, v: Val): string {
  if (v.lay.arms === null) {
    return val_own(v)[0];
  }
  const arms = Object.keys(v.lay.arms);
  repc(sc, "box " + sc.def + " " + arms.join("|") + " w" + v.lay.ks.length);''')
sub('''  const t = emit_alias(sc, v.ws[0], "u");
  return val_arms(sc, lay, t,''', '''  const t = emit_alias(sc, v.ws[0], "u");
  repc(sc, "unbox " + sc.def + " " + Object.keys(lay.arms).join("|") + " w" + lay.ks.length);
  return val_arms(sc, lay, t,''')
sub('''  const cls = cls_fit(exprs.length);
  const alloc = `heap_alloc(e, ${cls})`;''', '''  const cls = cls_fit(exprs.length);
  repc(sc, "node " + k + " w" + exprs.length);
  const alloc = `heap_alloc(e, ${cls})`;''')
sub('''  const words = live.flatMap(([, b]) => val_own(b.val));
  const name = seg_name("c");''', '''  const words = live.flatMap(([, b]) => val_own(b.val));
  repc(sc, "clo " + sc.def + " caps" + words.length);
  const name = seg_name("c");''')
sub('''function emit_jump(sc: Scope, args: string[], k: Name, bang = false): void {
  const fid = seg_fid(k);''', '''function emit_jump(sc: Scope, args: string[], k: Name, bang = false): void {
  const fid = seg_fid(k);
  if (k === CLO_APPLY) repc(sc, "apply " + sc.def);''')
sub('''      const y = call_eta(x)
        ?? (m.t.$ !== "Ref" && m.args.length === 0 ? m.h : null);''', '''      const y0 = call_eta(x);
      if (y0 !== null) repc(sc, "eta " + (m.t as Of<"Ref">).k + " in " + sc.def);
      const y = y0
        ?? (m.t.$ !== "Ref" && m.args.length === 0 ? m.h : null);''')
sub('''OUTLINE Term rfc_wrap(Env e, Term t, u32 cnt) {
''', '''OUTLINE Term rfc_wrap(Env e, Term t, u32 cnt) {
  REPC_INC(0);
''')
open(p, "w").write(s)
m = open(f"{dst}/main.ts").read()
open(f"{dst}/main.ts", "w").write(m)
m = open(f"{dst}/main.ts").read()
old = "    fs.writeFileSync(out, Comp.compile_book(book));"
assert m.count(old) == 1
m = m.replace(old, '''    const cc = Comp.compile_book(book);
    fs.writeFileSync(out + ".keys", ["rfc_wrap", ...Comp.repc_keys()].join("\\n") + "\\n");
    fs.writeFileSync(out, `#include <stdio.h>\n#include <stdlib.h>
static unsigned long long repc[65536];
#define REPC_INC(i) (repc[i]++)
__attribute__((destructor)) static void repc_dump(void) {
  FILE* f = fopen(getenv("REPC_OUT") ? getenv("REPC_OUT") : "/dev/stderr", "w");
  for (int i = 0; i < 65536; i++) if (repc[i]) fprintf(f, "%d %llu\\\\n", i, repc[i]);
  fclose(f);
}
` + cc);''')
open(f"{dst}/main.ts", "w").write(m)
