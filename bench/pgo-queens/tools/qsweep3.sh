#!/bin/sh
# Part 1 step 6: static hints (rare arms expected) against plain, symreg and lexer
Q=/private/tmp/bend-opt/pq-work
W=$Q/pgo/w
while pgrep -f "qsweep2.jsonl" > /dev/null || pgrep -f "qsweep1.jsonl" > /dev/null; do sleep 30; done
exec python3 $Q/tools/swp.py --rts --rounds 2 --out $Q/qsweep3.jsonl --wdir $Q/swp3 \
  symreg_main=$W/symreg/main/ms/x.c symreg_main_expect=$Q/qe/symreg_main_expect.c \
  symreg_int=$W/symreg/int/ms/x.c symreg_int_expect=$Q/qe/symreg_int_expect.c \
  lexer_main=$W/lexer/main/ms/x.c lexer_main_expect=$Q/qe/lexer_main_expect.c \
  lexer_int=$W/lexer/int/ms/x.c lexer_int_expect=$Q/qe/lexer_int_expect.c \
  queens_main_expect=$Q/qe/qm_expect.c:WL_FID_solve
