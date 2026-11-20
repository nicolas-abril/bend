#!/bin/sh
# Part 1: 16-position sweeps of every program, main / int / ref, plain and PGO.
cd /private/tmp/bend-opt/pq-work/pgo
B="queens symreg lexer hashmap histogram editdist bfs tree-matmul tree-radix tree-bitonic terrain kmeans mandelbrot raytrace nbody merkle gameoflife"
P="p-rbtree p-rbtree-unsafe p-rbtree-ck p-rbtree-ck-unsafe p-deriv p-cfold p-nqueens"
K=$(python3 -c "from progs import progs; print(' '.join(n for n in progs() if n.startswith('k-')))")
exec python3 pgo.py sweep --out sweep1.jsonl --rounds 1 --tries 2 --pmin 0.5 $B $P $K
