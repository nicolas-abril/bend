#!/usr/bin/env bash
# save.sh: copy results (jsonl, trace summaries) into the branch and push
H=$(cd "$(dirname "$0")" && pwd); W=/private/tmp/bend-opt/par/work
mkdir -p $H/results; cp $W/*.jsonl $W/*.txt $W/*.json $W/*.log $H/results/ 2>/dev/null
cd $H && git add -A results && git commit -qm "bench(par-split): results" && git push -q https://github.com/nicolas-abril/bend.git bench/par-split 2>&1 | grep -v remote
