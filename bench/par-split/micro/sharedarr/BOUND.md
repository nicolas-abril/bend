Count-contention bound (hand edit of exit's emitted C for m-sharedarr): in
spin_Array_fork, drop `_a_0 = term_keep(e, _a_0, 1);`; in spin_Array_join, drop
`term_sink(e, _b_0);`. Safe for this program only (every fork is joined).
Results in results/nocnt_bound.txt.
