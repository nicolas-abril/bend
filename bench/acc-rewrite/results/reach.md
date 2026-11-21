## Step 1: a nullary constructor that acts as a constant

Match chains over every runnable def (Base once; every other file its own defs).

| | count |
|---|---:|
| files checked | 1374 |
| match chains | 5218 |
|   on a builtin (Nat, U32, Bool, ...): not counted | 2061 |
|   on a declared type | 3157 |
|     whose type has a nullary constructor | 1202 |
|       and a constructor with fields (eligible) | 1016 |
|         eligible, scrutinee param | 856 |
|         eligible but every C with fields holds a T (recursive) | 715 |
|         hit, constants, no identities | 61 |
|         hit, constants + identities | 71 |
|         hit, constants or variables + identities (broad) | 78 |
|         hit only through a field of the type's own type (recursive: dropped) | 61 |
| files failing to check | 623 |
|         eligible, scrutinee field | 160 |

Hits by def (chains = match chains in the core; triv = chains where C0's arm equals C's for any constants, i.e. the match re-forms its scrutinee or ignores the fields; every = the constant tuple every consumer of the type in the program accepts, or the first def that refuses):

| group | file | def | type | C0 -> C | chains | triv | plain | ident | broad only | at every consumer | reached from main |
|---|---|---|---|---|---:|---:|---:|---:|---:|---|---|
(Of 75 rows, 17 are trivial in every chain: the match re-forms its scrutinee or ignores the fields, so any constants do; they are listed after the others.)

| base | BASE | Map.get.go | Map | MTip -> MLeaf | 1 | 0 | 1 | 1 | 0 | no (Map.ins.go) | None |
| base | BASE | Map.has.go | Map | MTip -> MLeaf | 1 | 0 | 1 | 1 | 0 | no (Map.ins.go) | None |
| base | BASE | Map.ins.go | Map | MTip -> MLeaf | 1 | 0 | 1 | 1 | 0 | no (Map.ins.go) | None |
| base | BASE | Map.pop.go | Map | MTip -> MLeaf | 1 | 0 | 1 | 1 | 0 | no (Map.ins.go) | None |
| base | BASE | Map.upd.go | Map | MTip -> MLeaf | 1 | 0 | 1 | 1 | 0 | no (Map.ins.go) | None |
| base | BASE | Maybe.default | Maybe | None -> Some | 1 | 0 | 0 | 0 | 1 | no (IO.join.go) | None |
| benches | bench/runtime/queens/main.bend | run.fin | Stats | Stat0 -> Stats | 1 | 0 | 0 | 1 | 0 | yes 0,0 | True |
| benches | bench/runtime/queens/main.bend | smerge | Stats | Stat0 -> Stats | 3 | 0 | 1 | 3 | 0 | yes 0,0 | True |
| benches | bench/runtime/queens/main.bend | solve | Stats | Stat0 -> Stats | 1 | 0 | 0 | 1 | 0 | yes 0,0 | True |
| benches | bench/runtime/symreg/main.bend | eval | Expr | Var -> Lit | 1 | 0 | 0 | 0 | 1 | no (eval) | True |
| benches | bench/runtime/tree-radix/main.bend | chk_join | Chk | Cnil -> Cval | 1 | 0 | 1 | 1 | 0 | no (chk_join) | True |
| benches | bench/runtime/tree-radix/main.bend | chk_out | Chk | Cnil -> Cval | 1 | 0 | 0 | 1 | 0 | no (chk_join) | True |
| demos | demos/app_slash_boss_3d/PROOF.bend | bend3d:Cells.merge | bend3d:Cells | bend3d:CNil -> bend3d:CLeaf | 1 | 0 | 1 | 1 | 0 | no (bend3d:Cells.merge) | False |
| demos | demos/app_slash_boss_3d/PROOF.bend | bend3d:Cells.put | bend3d:Cells | bend3d:CNil -> bend3d:CLeaf | 2 | 1 | 1 | 2 | 0 | no (bend3d:Cells.merge) | False |
| demos | demos/app_slash_boss_3d/PROOF.bend | main:Env.u32 | Maybe | None -> Some | 1 | 0 | 0 | 0 | 1 | no (main:Blast.over) | False |
| demos | demos/io_rollback_netcode/netcode.bend | Env.u32.go | Maybe | None -> Some | 1 | 0 | 0 | 0 | 1 | no (Post.put) | False |
| demos | demos/pure_hvm5_mini/PROOF.bend | main:app | main:Term | main:One -> main:Var | 1 | 0 | 1 | 1 | 0 | no (main:free_run) | False |
| demos | demos/pure_hvm5_mini/PROOF.bend | main:cel | main:Cell | main:Nul -> main:Sub | 1 | 0 | 1 | 1 | 0 | no (main:free_cov) | False |
| demos | demos/pure_hvm5_mini/PROOF.bend | main:dsp_go | main:Term | main:Era -> main:Var | 1 | 0 | 1 | 1 | 0 | no (main:free_run) | False |
| demos | demos/pure_hvm5_mini/PROOF.bend | main:dup | main:Term | main:Era -> main:Var | 1 | 0 | 1 | 1 | 0 | no (main:free_run) | False |
| demos | demos/pure_hvm5_mini/PROOF.bend | main:free_var | main:Cell | main:Nul -> main:Sub | 1 | 0 | 1 | 1 | 0 | no (main:free_cov) | False |
| demos | demos/pure_hvm5_mini/PROOF.bend | main:get | main:Term | main:One -> main:Var | 1 | 0 | 1 | 1 | 0 | no (main:free_run) | False |
| demos | demos/pure_hvm5_mini/PROOF.bend | main:go_cov | main:Cell | main:Nul -> main:Num | 1 | 0 | 1 | 1 | 0 | yes 0 | False |
| demos | demos/pure_hvm5_mini/PROOF.bend | main:go_var | main:Cell | main:Nul -> main:Sha | 1 | 0 | 1 | 1 | 0 | no (main:free_cov) | False |
| demos | demos/pure_hvm5_mini/PROOF.bend | main:inst.get | main:Term | main:Era -> main:Var | 1 | 0 | 1 | 1 | 0 | no (main:free_run) | False |
| demos | demos/pure_hvm5_mini/PROOF.bend | main:inst.mat | main:Fz | main:FLam -> main:FRoot | 1 | 0 | 1 | 1 | 0 | no (main:inst.mat.no) | False |
| demos | demos/pure_hvm5_mini/PROOF.bend | main:inst.mat | main:Term | main:Era -> main:Var | 1 | 0 | 1 | 1 | 0 | no (main:free_run) | False |
| demos | demos/pure_hvm5_mini/PROOF.bend | main:inst.use | main:Term | main:Era -> main:Var | 1 | 0 | 1 | 1 | 0 | no (main:free_run) | False |
| demos | demos/pure_hvm5_mini/PROOF.bend | main:mat | main:Term | main:One -> main:Var | 1 | 0 | 1 | 1 | 0 | no (main:free_run) | False |
| demos | demos/pure_hvm5_mini/PROOF.bend | main:nf | main:Term | main:Era -> main:Var | 1 | 0 | 1 | 1 | 0 | no (main:free_run) | False |
| demos | demos/pure_hvm5_mini/PROOF.bend | main:run | main:Term | main:Era -> main:Won | 1 | 0 | 1 | 1 | 0 | no (main:inst.mat) | False |
| demos | demos/pure_hvm5_mini/PROOF.bend | main:term_pak | main:Tpl | main:TEra -> main:TVar | 1 | 0 | 1 | 1 | 0 | no (main:inst) | False |
| tests | tests/compile/array_single_slot.bend | pairsum | Pr | Ep -> MkPr | 1 | 0 | 0 | 1 | 0 | yes 0,0 | True |
| tests | tests/compile/family_cyclic_layout.bend | wide | Nest | End -> More | 1 | 0 | 1 | 1 | 0 | no (read) | True |
| tests | tests/compile/nodeless_dup_drop.bend | box_val | BoxB | NilB -> TwoB | 1 | 0 | 0 | 1 | 0 | yes 0,0 | True |
| tests | tests/flatten/lambda_match_sugar.bend | main | Foo | C -> A | 1 | 0 | 0 | 0 | 1 | no (main) | True |
| tests | tests/import/unsafe-law/fill.bend | Map.get.go | Map | MTip -> MLeaf | 1 | 0 | 1 | 1 | 0 | no (Map.ins.go) | False |
| tests | tests/import/unsafe-law/fill.bend | Map.has.go | Map | MTip -> MLeaf | 1 | 0 | 1 | 1 | 0 | no (Map.ins.go) | False |
| tests | tests/import/unsafe-law/fill.bend | Map.ins.go | Map | MTip -> MLeaf | 1 | 0 | 1 | 1 | 0 | no (Map.ins.go) | False |
| tests | tests/import/unsafe-law/fill.bend | Map.pop.go | Map | MTip -> MLeaf | 1 | 0 | 1 | 1 | 0 | no (Map.ins.go) | False |
| tests | tests/import/unsafe-law/fill.bend | Map.upd.go | Map | MTip -> MLeaf | 1 | 0 | 1 | 1 | 0 | no (Map.ins.go) | False |
| tests | tests/import/unsafe-law/fill.bend | Maybe.default | Maybe | None -> Some | 1 | 0 | 0 | 0 | 1 | no (IO.join.go) | False |
| tests | tests/io/chan_try_wake_timers.bend | val | Maybe | None -> Some | 1 | 0 | 1 | 1 | 0 | yes 0 | True |
| tests | tests/io/channel_fork_join.bend | got | Maybe | None -> Some | 1 | 0 | 1 | 1 | 0 | no (IO.join.go) | True |
| tests | tests/io/cid_capture.bend | keep | Forgery | cid_capture_lib.None -> cid_capture_lib.Con | 1 | 0 | 0 | 1 | 0 | yes 0,0,0 | True |
| tests | tests/io/foreign_shared.bend | tree.sum | Tree | Empty -> Leaf | 1 | 0 | 1 | 1 | 0 | yes 0 | True |
| tests | tests/io/marshal_native_forms.bend | unwrap | Maybe | None -> Some | 1 | 0 | 1 | 1 | 0 | yes 0n | True |
| tests | tests/io/nat_host_chan.bend | got | Maybe | None -> Some | 1 | 0 | 1 | 1 | 0 | yes 0n | True |
| tests | tests/reg/framed_cell_dep.bend | Map.get.go | Map | MTip -> MLeaf | 1 | 0 | 1 | 1 | 0 | no | False |
| tests | tests/reg/framed_cell_dep.bend | Map.has.go | Map | MTip -> MLeaf | 1 | 0 | 1 | 1 | 0 | no | False |
| tests | tests/reg/framed_cell_dep.bend | Map.ins.go | Map | MTip -> MLeaf | 1 | 0 | 1 | 1 | 0 | no | False |
| tests | tests/reg/framed_cell_dep.bend | Map.pop.go | Map | MTip -> MLeaf | 1 | 0 | 1 | 1 | 0 | no | False |
| tests | tests/reg/framed_cell_dep.bend | Map.upd.go | Map | MTip -> MLeaf | 1 | 0 | 1 | 1 | 0 | no | False |
| tests | tests/reg/framed_cell_dep.bend | Maybe.default | Maybe | None -> Some | 1 | 0 | 0 | 0 | 1 | no | False |
| tests | tests/rfc/drop_spine_wordless.bend | get | PL | PNil -> PCon | 1 | 0 | 1 | 1 | 0 | yes *,0,* | True |
| tests | tests/run/evening_program.bend | rdn.fin | Maybe | None -> Some | 1 | 0 | 1 | 1 | 0 | no (rdu.fin) | True |
| tests | tests/run/fork_shared_flat.bend | use | Maybe | None -> Some | 1 | 0 | 1 | 1 | 0 | yes 0 | True |
| tests | tests/run/list_map_fold_ops.bend | mmul10 | Map | MTip -> MLeaf | 1 | 0 | 0 | 1 | 0 | no (mfold) | True |
| benches | bench/runtime/symreg/main.bend | esize | Expr | Var -> Lit | 1 | 1 | 1 | 1 | 0 | no (eval) | True |
| demos | demos/pure_hvm5_mini/PROOF.bend | main:dsp_go | main:Tpl | main:TEra -> main:TVar | 1 | 1 | 1 | 1 | 0 | no (main:inst) | False |
| demos | demos/pure_hvm5_mini/PROOF.bend | main:free_cov | main:Cell | main:Nul -> main:Num | 1 | 1 | 1 | 1 | 0 | yes 0 | False |
| demos | demos/pure_hvm5_mini/PROOF.bend | main:free_run | main:Term | main:Era -> main:Won | 1 | 1 | 1 | 1 | 0 | no (main:inst.mat) | False |
| demos | demos/pure_hvm5_mini/PROOF.bend | main:inst.app | main:Fz | main:FLam -> main:FRoot | 1 | 1 | 1 | 1 | 0 | no (main:inst.mat.no) | False |
| demos | demos/pure_hvm5_mini/PROOF.bend | main:inst.drp | main:Fz | main:FLam -> main:FRoot | 1 | 1 | 1 | 1 | 0 | no (main:inst.mat.no) | False |
| demos | demos/pure_hvm5_mini/PROOF.bend | main:inst.get | main:Fz | main:FLam -> main:FRoot | 1 | 1 | 1 | 1 | 0 | no (main:inst.mat.no) | False |
| demos | demos/pure_hvm5_mini/PROOF.bend | main:inst.lam | main:Fz | main:FLam -> main:FRoot | 1 | 1 | 1 | 1 | 0 | no (main:inst.mat.no) | False |
| demos | demos/pure_hvm5_mini/PROOF.bend | main:inst.use | main:Fz | main:FLam -> main:FRoot | 1 | 1 | 1 | 1 | 0 | no (main:inst.mat.no) | False |
| demos | demos/pure_hvm5_mini/PROOF.bend | main:num | main:Cell | main:Nul -> main:Sub | 1 | 1 | 1 | 1 | 0 | no (main:free_cov) | False |
| demos | demos/pure_hvm5_mini/PROOF.bend | main:settle_ded | main:Cell | main:Nul -> main:Sha | 1 | 1 | 1 | 1 | 0 | no (main:free_cov) | False |
| demos | demos/pure_hvm5_mini/PROOF.bend | main:settle_park | main:Cell | main:Nul -> main:Sub | 1 | 1 | 1 | 1 | 0 | no (main:free_cov) | False |
| tests | tests/gfx/fullscreen_input.bend | line | Event | Close -> Key | 1 | 1 | 1 | 1 | 0 | yes *,* | True |
| tests | tests/gfx/window_events.bend | line | Event | Close -> Key | 1 | 1 | 1 | 1 | 0 | yes *,* | True |
| tests | tests/proof/monad_laws.bend | monad_assoc | Mb | MNone -> MSome | 1 | 1 | 1 | 1 | 0 | no | False |
| tests | tests/proof/monad_laws.bend | monad_right_id | Mb | MNone -> MSome | 1 | 1 | 1 | 1 | 0 | no | False |
| tests | tests/rfc/drop_array_spine.bend | at_sum | AT | ANil -> ACon | 1 | 1 | 1 | 1 | 0 | no (at_sum) | True |

## Step 2: a returned record whose fields are only added into parameters

| | count |
|---|---:|
| calls with a call to a def as an argument | 5797 |
|   parameter taken as mat | 1686 |
|   parameter taken as none | 438 |
|   parameter taken as lam | 3559 |
|   parameter taken as mixed | 114 |
|     used only as an associative op into another value (lam) | 43 |
|     used only as an add into another value (mat) | 17 |
|     used only as an associative op into another value (mat) | 22 |
|     used only as an add into another value (lam) | 13 |

Hits (use add) and near hits (use assoc: or, xor, mul, and, min, max as well):

| group | file | def | outer(inner) at arg | sites | param | type | use | inner may return a nullary ctor | reached from main |
|---|---|---|---|---:|---|---|---|---|---|
| benches | bench/runtime/histogram/main.bend | main | Bufs.sized(depth) at 0 | 1 | lam |  | assoc | no | True |
| benches | bench/runtime/histogram/main.bend | main | Bufs.sized(size) at 2 | 1 | lam |  | assoc | no | True |
| benches | bench/runtime/histogram/main.bend | main | run(depth) at 2 | 1 | lam |  | assoc | no | True |
| benches | bench/runtime/merkle/main.bend | pverify | mrk(sel) at 1 | 1 | lam |  | assoc | no | True |
| benches | bench/runtime/merkle/main.bend | main | mrk(pverify) at 1 | 1 | lam |  | assoc | no | True |
| benches | bench/runtime/queens/main.bend | solve | solve(solve) at 11 | 1 | mat | Stats | add | no | True |
| demos | demos/app_slash_boss_3d/PROOF.bend | main:Sums.next | main:Sums.add(main:Probe.ms) at 2 | 1 | lam |  | add | no | True |
| demos | demos/app_slash_boss_3d/PROOF.bend | main:Sums.next | main:Sums.add(main:Probe.ms) at 3 | 1 | lam |  | add | no | True |
| demos | demos/app_slash_boss_3d/PROOF.bend | main:Sums.next | main:Sums.add(main:Probe.ms) at 4 | 1 | lam |  | add | no | True |
| demos | demos/app_slash_boss_3d/PROOF.bend | main:Sums.next | main:Sums.add(main:Probe.ms) at 5 | 1 | lam |  | add | no | True |
| demos | demos/app_slash_boss_3d/PROOF.bend | main:Sums.next | main:Sums.add(main:Probe.ms) at 6 | 1 | lam |  | add | no | True |
| demos | demos/app_win_is_bug_2d/PROOF.bend | chk | imp(okpos) at 1 | 1 | lam |  | assoc | no | False |
| demos | demos/app_win_is_bug_2d/PROOF.bend | fchk | imp(Bool.not) at 1 | 1 | lam |  | assoc | True,False | False |
| demos | demos/io_rollback_netcode/netcode.bend | Net.finalize | Time.tick(Game.rate) at 1 | 1 | lam |  | assoc | no | False |
| demos | demos/io_rollback_netcode/netcode.bend | Net.pong | Time.tick(Game.rate) at 1 | 1 | lam |  | assoc | no | False |
| demos | demos/io_rollback_netcode/netcode.bend | Link.tick | Time.tick(Clock.server) at 0 | 1 | lam |  | assoc | no | False |
| demos | demos/io_rollback_netcode/netcode.bend | Link.tick | Time.tick(Game.rate) at 1 | 1 | lam |  | assoc | no | False |
| demos | demos/io_rollback_netcode/netcode.bend | Link.lag | Time.tick(Game.rate) at 1 | 1 | lam |  | assoc | no | False |
| demos | demos/io_rollback_netcode/netcode.bend | Client.echo | Time.tick(Game.rate) at 1 | 1 | lam |  | assoc | no | False |
| demos | demos/io_rollback_netcode/netcode.bend | Client.post.go | Time.tick(Game.rate) at 1 | 1 | lam |  | assoc | no | False |
| demos | demos/io_rollback_netcode/walkers_demo.bend | netcode:Client.post.go~0 | netcode:Time.tick(netcode:Game.rate) at 1 | 1 | lam |  | assoc | no | True |
| demos | demos/io_rollback_netcode/walkers_demo.bend | netcode:Client.echo~0 | netcode:Time.tick(netcode:Game.rate) at 1 | 1 | lam |  | assoc | no | True |
| demos | demos/io_rollback_netcode/walkers_demo.bend | netcode:Net.pong~0 | netcode:Time.tick(netcode:Game.rate) at 1 | 1 | lam |  | assoc | no | True |
| demos | demos/io_rollback_netcode/walkers_demo.bend | netcode:Net.finalize~0 | netcode:Time.tick(netcode:Game.rate) at 1 | 1 | lam |  | assoc | no | True |
| demos | demos/io_rollback_netcode/walkers_demo.bend | netcode:Link.tick~0 | netcode:Time.tick(netcode:Clock.server) at 0 | 1 | lam |  | assoc | no | True |
| demos | demos/io_rollback_netcode/walkers_demo.bend | netcode:Link.tick~0 | netcode:Time.tick(netcode:Game.rate) at 1 | 1 | lam |  | assoc | no | True |
| demos | demos/io_rollback_netcode/walkers_demo.bend | netcode:Link.lag~0 | netcode:Time.tick(netcode:Game.rate) at 1 | 1 | lam |  | assoc | no | True |
| demos | demos/io_rollback_netcode/walkers_test.bend | World.hash.go | World.mix(World.mix) at 0 | 1 | lam |  | assoc | no | True |
| demos | demos/pure_hvm5_mini/PROOF.bend | main:term_pak | main:run_word(main:pick) at 1 | 1 | lam |  | assoc | no | True |
| kernels | koru/bend/exprtree/exprtree.bend | eval | addM(eval) at 0 | 1 | lam |  | add | no | True |
| kernels | koru/bend/exprtree/exprtree.bend | eval | addM(eval) at 1 | 1 | lam |  | add | no | True |
| kernels | koru/bend/exprtree/exprtree.bend | go | addM(runOne) at 1 | 1 | lam |  | add | no | True |
| kernels | koru/bend/listops/listops.bend | runOne | pairSum(sumBelow) at 0 | 1 | mat | Sigma | add | no | True |
| kernels | koru/bend/listops/listops.bend | go | addM(runOne) at 1 | 1 | lam |  | add | no | True |
| tests | tests/base/rand.bend | go.b | go.c(rrange) at 2 | 1 | mat | Sigma | add | no | True |
| tests | tests/check/cop_many_binder_000.bend | main | unp(dup) at 0 | 1 | mat | Sigma | add | no | True |
| tests | tests/check/kind_terms.bend | main | add(dup) at 0 | 1 | mat | Sigma | add | no | True |
| tests | tests/check/wide_record_cost.bend | main.out | top(rot) at 0 | 1 | mat | R8 | add | no | True |
| tests | tests/compile/boxed_ctor_reuse.bend | main.out | get(mk) at 0 | 1 | mat | Point | add | no | True |
| tests | tests/compile/flat_ctor_args.bend | mkin | lenof(mkin) at 0 | 1 | mat | Inn | add | no | True |
| tests | tests/compile/flat_record_suite.bend | main.go | sum8(mk8) at 0 | 1 | mat | S8 | add | no | True |
| tests | tests/compile/flat_record_suite.bend | main.out | main.go(rec4) at 1 | 1 | mat | S4 | add | no | True |
| tests | tests/compile/loop_record_unpack_000.bend | main.out | sum(go) at 0 | 1 | mat | St | add | no | True |
| tests | tests/compile/once_box_return.bend | main | sum(get) at 0 | 1 | mat | Duo | add | no | True |
| tests | tests/flatten/destructure_let_000.bend | go | go.at(mk) at 0 | 1 | mat | Duo | assoc | no | False |
| tests | tests/flatten/destructure_let_000.bend | main | go.at(swap) at 0 | 1 | mat | Duo | assoc | no | True |
| tests | tests/flatten/destructure_let_000_go.bend | main | go.at(mk) at 0 | 1 | mat | Duo | assoc | no | True |
| tests | tests/flatten/destructure_let_000_go_at.bend | go | main(mk) at 0 | 1 | mat | Duo | assoc | no | False |
| tests | tests/flatten/destructure_let_000_mk.bend | go | go.at(main) at 0 | 1 | mat | Duo | assoc | no | False |
| tests | tests/flatten/taint_hoist_capture.bend | main.out | add3(sum8) at 0 | 1 | lam |  | add | no | True |
| tests | tests/import/unsafe-law/fill.bend | Word.adc | Bool.full_add(Bool.not) at 1 | 1 | lam |  | assoc | True,False | False |
| tests | tests/io/marshal_array_depth.bend | verify | verify(Bool.and) at 2 | 1 | lam |  | assoc | False | True |
| tests | tests/parse/def_typed.bend | main.go | add(len) at 0 | 1 | lam |  | add | no | True |
| tests | tests/parse/def_typed.bend | main.go | add(len) at 1 | 1 | lam |  | add | no | True |
| tests | tests/reg/erased_field_call.bend | rs15 | us2(cu8) at 1 | 1 | lam |  | assoc | no | True |
| tests | tests/reg/framed_cell_dep.bend | Word.adc | Bool.full_add(Bool.not) at 1 | 1 | lam |  | assoc | True,False | False |
| tests | tests/reg/rwt_type_share.bend | rec | use(unhide) at 0 | 1 | mat | Rec | add | no | True |
| tests | tests/reg/rwt_type_share.bend | nest | use(unhide) at 0 | 1 | mat | Rec | add | no | True |
| tests | tests/reg/rwt_type_share.bend | peek | use(unhide) at 0 | 1 | mat | Rec | add | no | True |
| tests | tests/run/binary_search.bend | go.c | go.d(bs) at 1 | 1 | mat | Sigma | add | no | True |
| tests | tests/run/nat_mul_wide.bend | rows | row(big) at 1 | 1 | lam |  | assoc | no | True |
| tests | tests/run/nat_mul_wide.bend | rows | row(big) at 0 | 1 | lam |  | assoc | no | True |
| tests | tests/run/spare_reuse.bend | go | sum(swap) at 0 | 1 | mat | Duo | add | no | True |
| tests | tests/run/word_compare.bend | main.out | row(bu) at 0 | 1 | lam |  | add | no | True |
| base | BASE | Word.adc | Bool.full_add(Bool.not) at 1 | 1 | lam |  | assoc | True,False | None |

## The broader family: types with an absent / present constructor

Declared types (Base once, then each file's own): 472; with a nullary constructor and one with fields: 112; Option-shaped (exactly those two): 81.

| | count |
|---|---:|
| matches on a recursive type with a nullary end (list-like): not the family | 722 |
| matches on a wider-shaped type | 156 |
| matches on a option-shaped type | 158 |
|   option: C0 is C with constant fields (step 1) | 21 |
|   option: fields only combined into other values (alongside) | 6 |
|   wider: C0 is C with fields from variables in scope (default) | 2 |
|   wider: C0 is C with constant fields (step 1) | 63 |
|   option: C0 is C with fields from variables in scope (default) | 5 |
|   wider: fields only combined into other values (alongside) | 1 |

Option-shaped types:

AT (tests/rfc/drop_array_spine.bend), Arms (tests/check/mutual_types_param.bend), AuditChain (tests/reg/brw_audit2_array_field.bend), AuditPayload (tests/reg/brw_audit_unbox_root.bend), AuditPick (tests/reg/brw_audit2_unbox_generic.bend), AuditShelf (tests/reg/brw_audit2_unbox_generic.bend), AuditSum (tests/reg/brw_audit2_fresh_box_root.bend), AuditTree (tests/reg/brw_audit3_twin_owner.bend), B (tests/compile/gpu_reach_closure_mutual.bend), BST (tests/run/bst_insert.bend), BoxB (tests/compile/nodeless_dup_drop.bend), Ch (tests/compile/gpu_reach_closure_deep.bend), Chain (bench/runtime/hashmap/main.bend), Chk (bench/runtime/tree-radix/main.bend), Choice (tests/check/dead_default_residual.bend), CtL (tests/import/comp_splice_boundary.bend), Cx (tests/flatten/dead_residue_elision_004.bend), D0 (tests/reg/spin_refs_dead_seg.bend), D1 (tests/reg/erased_field_call.bend), FK (demos/pure_hvm5_mini/main.bend), Fns (tests/compile/js_closure_captures.bend), Forest (tests/check/mutual_types.bend), Forgery (tests/io/cid_capture.bend), ForkChain (tests/reg/brw_audit_fork_flip.bend), Got (tests/check/convoy_dependent.bend), Items (tests/reg/fork_spin_owner.bend), KForest (tests/proof/descent_rebuilt_shell.bend), KTree (tests/proof/descent_rebuilt_shell.bend), L (tests/cost/list_fold.bend), List (tests/import/sugar_list_own.bend), Ll (tests/compile/spin_machine.bend), LoopChain (tests/reg/brw_audit_unfold_zero.bend), Lst (tests/compile/word_contraction_dup.bend), M (tests/compile/record_wide_boxed_params.bend), ML (tests/rfc/drop_spine.bend), MN (tests/state/eval_case_tree_000.bend), Maybe (tests/import/unsafe-law/fill.bend), Mb (tests/proof/monad_laws.bend), N (tests/check/conversion_shared_cells_self_value.bend), N6 (tests/check/proof_computation_cost.bend), N7 (tests/stats/check_budget.bend), N8 (tests/stats/subst_zero.bend), N9 (tests/check/bystander_hypothesis_cost.bend), Nat (tests/import/unsafe-law/fill.bend), Nd (tests/check/capture_price_twin_000.bend), Ne (tests/check/capture_price_twin_001.bend), Nest (tests/compile/family_cyclic_layout.bend), Nf (tests/check/computed_match_specialize.bend), Nk (tests/check/type_family_eval.bend), Nl (tests/check/type_family_lambda.bend), Nm (tests/check/dependent_function_arg.bend), Nn (tests/parse/ctor_row_layout.bend), Nn2 (tests/parse/datatype_declaration_form.bend), Nn3 (tests/parse/do_head_sugar.bend), Nn5 (tests/parse/grammar_capability_pins.bend), Nq (tests/check/dependent_telescope.bend), Ns (tests/check/equality_is_data.bend), Nt (tests/compile/default_rebind_000.bend), Nx (tests/import/base_prelude.bend), OL (tests/rfc/drop_spine.bend), Opt (tests/compile/array_static_default.bend), PL (tests/rfc/drop_spine_wordless.bend), PairChain (tests/reg/brw_audit_mixed_flat.bend), Path (bench/runtime/merkle/main.bend), PayloadChain (tests/reg/brw_audit_unbox_root.bend), Pr (tests/compile/array_single_slot.bend), R (tests/flatten/computed_operator_match_002.bend), RL (tests/rfc/drop_spine.bend), Spine (tests/proof/refined_proof_copy.bend), Stats (bench/runtime/queens/main.bend), String (tests/import/unsafe-law/fill.bend), Tris (demos/app_slash_boss_3d/bend3d.bend), TwinChain (tests/reg/brw_audit_twins.bend), WL (tests/rfc/drop_spine_wide.bend), Word (tests/check/safe_parameterized_box_word.bend), Xs (tests/compile/record_wide_boxed_params.bend), Ys (tests/reg/brw_field_store.bend), bend3d:Tris (demos/app_slash_boss_3d/PROOF.bend), main:FK (demos/pure_hvm5_mini/PROOF.bend), marshal_imported_nullary_type:Tag (tests/io/marshal_imported_nullary.bend), sugar_list_own_lib:List (tests/import/sugar_list_own.bend)

Matches whose fields are only combined into other values (the `ret` shape):

| group | file | def | type | chains |
|---|---|---|---|---:|
| benches | bench/runtime/queens/main.bend | solve | Stats | 1 |
| benches | bench/runtime/queens/main.bend | smerge | Stats | 1 |
| tests | tests/compile/array_single_slot.bend | pairsum | Pr | 1 |
| tests | tests/compile/array_static_default.bend | osum | Opt | 1 |
| tests | tests/compile/nodeless_dup_drop.bend | box_val | BoxB | 1 |
| tests | tests/flatten/lambda_match_sugar.bend | main | Foo | 1 |
| tests | tests/io/cid_capture.bend | keep | Forgery | 1 |

Hook errors: 0; files that did not check: 623
