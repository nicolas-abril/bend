import json,sys,re,collections
rows=[json.loads(l) for l in open(sys.argv[1])]
PRINT=re.compile(r"^(U32\.show|Nat\.show|F32\.show|String\.|IO\.|List\.length|U32\.read|Nat\.read|U32\.hex|main)")
def prog(r): return r['file'].replace('/Users/macolas/Software/bend-benchmarks/','').replace('/main.bend','')
def hot(s,r): return s['depth']>=1 and not PRINT.match(s['d'])
def inner(s,r): return s['depth']==r['maxd'] and r['maxd']>=1 and not PRINT.match(s['d'])
C=collections.defaultdict(lambda: collections.Counter())
P=collections.defaultdict(set)
PI=collections.defaultdict(set)
for r in rows:
    p=prog(r)
    for s in r['sites']:
        k=s['kind']
        if k=='lamarg': k='lamarg.'+('rec' if s['crec'] else 'nonrec')
        if k=='push':
            if s['sink']>0: k2='push.sink' + ('.2217' if s['s2217']==s['sink'] else '.more')
            else: k2=None
            for kk in ['push']+([k2] if k2 else []):
                C[kk]['all']+=1
                if hot(s,r): C[kk]['hot']+=1; P[kk].add(p)
                if inner(s,r): C[kk]['inner']+=1; PI[kk].add(p)
            continue
        if k in('inv','cse'): k=k+'.'+('far' if 'far' in s['ek'] else 'chk' if 'chk' in s['ek'] else 'flat' if 'flat' in s['ek'] else 'op')
        if k=='inv' : pass
        C[k]['all']+=1
        if hot(s,r): C[k]['hot']+=1; P[k].add(p)
        if inner(s,r): C[k]['inner']+=1; PI[k].add(p)
print("%-22s %7s %7s %7s %6s %6s"%("kind","all","hot","inner","progH","progI"))
for k in sorted(C): print("%-22s %7d %7d %7d %6d %6d"%(k,C[k]['all'],C[k]['hot'],C[k]['inner'],len(P[k]),len(PI[k])))
