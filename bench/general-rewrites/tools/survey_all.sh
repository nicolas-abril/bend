#!/bin/bash
# survey every benchmark program: one JSON line each into $1
OUT=$1; : > $OUT
BB=/Users/macolas/Software/bend-benchmarks
find $BB -name '*.bend' -not -path '*/.git/*' -not -path '*/reference/*' -not -path '*/tools/*' | sort | while read f; do
  d=$(dirname $f)
  r=$(cd $d && ~/Software/supgen-bend/limit 300 6144 bun /private/tmp/bend-opt/gen/tools/survey.ts $f 2>/tmp/sv_err.txt)
  if [ -n "$r" ]; then echo "$r" >> $OUT; else echo "{\"file\":\"$f\",\"err\":$(head -c 300 /tmp/sv_err.txt | python3 -c 'import json,sys;print(json.dumps(sys.stdin.read()))')}" >> $OUT; fi
done
