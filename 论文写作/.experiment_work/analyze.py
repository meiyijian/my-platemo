from pathlib import Path
import json,re,csv
from collections import Counter,defaultdict
import numpy as np
base=Path(__file__).parent
books=json.loads((base/'books.json').read_text(encoding='utf-8'))
pat=re.compile(r'\s*([\d.]+e[+-]\d+)\s*\(([\d.]+e[+-]\d+)\)\s*([+=-])?\s*$',re.I)
def parse(x):
    m=pat.fullmatch(str(x))
    return (float(m[1]),float(m[2]),m[3]) if m else None
def sheet(path):
    rows=next(iter(books[path].values()))
    return rows[0],[dict(zip(rows[0],r)) for r in rows[1:] if r and re.fullmatch(r'(DTLZ|WFG)\d+',str(r[0]))]
for m in [3,5,8,10,12,20]:
    h,rr=sheet(f'最新版算法总实验\\{m}目标.xlsx')
    alg=h[h.index('D')+1:] if 'FE' not in h else h[h.index('FE')+1:]
    target=alg[-1]
    print('MAIN',m,'META', {x:sorted({str(r.get(x)) for r in rr}) for x in ['N','M','D','FE']})
    total=Counter()
    for a in alg[:-1]:
        c=Counter(parse(r[a])[2] for r in rr if parse(r[a]))
        total.update(c)
        print(a,'W/T/L',c['-'],c['='],c['+'])
    print('ALL',dict(total),'BEST',sum(parse(r[target])[0]<=min(parse(r[a])[0] for a in alg[:-1]) for r in rr))
    common=['REMO','PIEA','MCEAD','KRVEA']
    cc=Counter(parse(r[a])[2] for r in rr for a in common)
    effects=[100*(parse(r[a])[0]-parse(r[target])[0])/parse(r[a])[0] for r in rr for a in common]
    print('COMMON',dict(cc),'median',np.median(effects),'mean',np.mean(effects))
    if m in [10,20]:
        for r in rr:
            print(r['Problem'], ' / '.join(a+': '+r[a] for a in alg))
for m in [10,20]:
    h,rr=sheet(f'消融实验\\两个模块的消融实验\\full_{m}.xlsx')
    alg=h[5:]
    valid=[r for r in rr if r['M']==m]
    print('ABLATION',m,'EXCLUDED',[(r['Problem'],r['M']) for r in rr if r['M']!=m])
    for a in alg:
        c=Counter(parse(r[a])[2] for r in valid)
        print(a,'W/T/L',c['-'],c['='],c['+'],'best',sum(parse(r[a])[0]==min(parse(r[x])[0] for x in alg) for r in valid))
    for r in valid:
        if r['Problem'] in ['DTLZ7','WFG3','WFG7','WFG9']: print(r)
for sub in ['', '二十目标\\', 'IGDp\\']:
    p=f'消融实验\\候选解模块\\{sub}Ada_Mao_SDEonly_UniformMix.xlsx'
    h,rr=sheet(p)
    als=[a for a in h if isinstance(a,str) and any(a.endswith(s) for s in ['AlwaysExplore','AlwaysIndicator','LinearSchedule','UniformMix'])]
    print('ROUTES',sub, 'META', {x:sorted({str(r.get(x)) for r in rr}) for x in ['M','D']})
    for a in als:
        c=Counter(parse(r[a])[2] for r in rr)
        print(a,'W/T/L',c['-'],c['='],c['+'],'best',sum(parse(r[a])[0]==min(parse(r[x])[0] for x in als) for r in rr))
    for r in rr:
        if r['Problem'] in ['DTLZ7','WFG3','WFG7']: print(r['Problem'], {a:r[a] for a in als})
root=Path(r'C:\Users\lsx\Desktop\AdaMao实验表')
def csvrows(p):
    with p.open(encoding='utf-8-sig',newline='') as f:return list(csv.DictReader(f))
rr=csvrows(root/'Stage2_LabelCausalAblation/screening/analysis/Stage2_pairwise_overlap.csv')
for pair in ['L1_vs_L3','L2_vs_L3','L3_vs_L4','L3_vs_L5']:
    for b in ['Hybrid','AnchorNative']:
        vv=[float(r['MeanJaccard']) for r in rr if r['Pair']==pair and r['behavior']==b]
        if vv:print('OVERLAP',pair,b,len(vv),np.mean(vv),min(vv),max(vv))
print('PAIRS',sorted({r['Pair'] for r in rr}))
rr=csvrows(root/'Stage1_UniformMix_LabelValidation/screening/analysis/Stage1_trajectory_summary.csv')
for b in ['Hybrid','AnchorNative']:
    rows=[r for r in rr if r['behavior']==b]
    print('TRAJECTORY',b,len(rows),{k:sum(float(r[k]) for r in rows) for k in ['generations','indicatorGens','exploreGens','fallbackGens']})
rr=csvrows(root/'Stage2_LabelCausalAblation/screening/analysis/Stage2_stability_summary.csv')
for b in ['Hybrid','AnchorNative']:
    for d in ['0.05','0.10']:
        vals=[float(r['MeanRetainedJaccard']) for r in rr if r['Variant']=='L3' and float(r['DropFraction'])==float(d) and r['behavior']==b]
        print('STABILITY',b,d,len(vals),np.mean(vals))
