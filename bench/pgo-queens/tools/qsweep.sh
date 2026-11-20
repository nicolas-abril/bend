#!/bin/sh
# queens: ladder, Bend main/int, hand edits, respellings; 16 positions
Q=/private/tmp/bend-opt/pq-work
cd $Q/qt
exec python3 $Q/tools/swp.py --rts --rounds ${ROUNDS:-1} --out ${OUT:-$Q/qsweep1.jsonl} --wdir $Q/swp \
  l0=l0.c:solve l1a=l1.c:solve@-DNOFUEL\ -DNORET l1b=l1.c:solve@-DNORET l1c=l1.c:solve l2=l2.c:solve \
  l3=l3.c:main l4=l4.c:s_solve l4_twok=l4.c:s_solve@-DTWO_K \
  bend_main=$Q/qe/qm_base.c:WL_FID_solve bend_int=$Q/qe/qi_base.c:WL_FID_solve \
  main_sat=$Q/qe/qm_sat.c:WL_FID_solve main_rec=$Q/qe/qm_rec.c:WL_FID_solve main_sat_rec=$Q/qe/qm_sat_rec.c:WL_FID_solve main_nofuel=$Q/qe/qm_nofuel.c:WL_FID_solve \
  int_sat=$Q/qe/qi_sat.c:WL_FID_solve int_rec=$Q/qe/qi_rec.c:WL_FID_solve int_sat_rec=$Q/qe/qi_sat_rec.c:WL_FID_solve int_nofuel=$Q/qe/qi_nofuel.c:WL_FID_solve \
  int_early=$Q/qe/qi_early.c:WL_FID_solve int_early_rec=$Q/qe/qi_early_rec.c:WL_FID_solve \
  r1_main=$Q/qr/r1_m.c:WL_FID_solve r1_int=$Q/qr/r1_i.c:WL_FID_solve r2_main=$Q/qr/r2_m.c:WL_FID_solve r2_int=$Q/qr/r2_i.c:WL_FID_solve \
  r3_main=$Q/qr/r3_m.c:WL_FID_solve r3_int=$Q/qr/r3_i.c:WL_FID_solve
