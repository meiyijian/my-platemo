from pathlib import Path
import json,re
from collections import Counter
import numpy as np
import pandas as pd

work=Path(__file__).parent
paper=work.parent/'HPDC-MaOEA.tex'
books=json.loads((work/'books.json').read_text(encoding='utf-8'))
repo=Path(r'D:\PlatEMO-master\PlatEMO-master\PlatEMO\Experiments')
pat=re.compile(r'\s*([\d.]+e[+-]\d+)\s*\(([\d.]+e[+-]\d+)\)\s*([+=-])?\s*$',re.I)
def parse(x):
    m=pat.fullmatch(str(x))
    if not m: raise ValueError(x)
    return float(m[1]),float(m[2]),m[3],m[1],m[2]
def sheet(path):
    rows=next(iter(books[path].values()))
    return rows[0],[dict(zip(rows[0],r)) for r in rows[1:] if r and re.fullmatch(r'(DTLZ|WFG)\d+',str(r[0]))]
def line(v): return ' & '.join(map(str,v))+r' \\'
def table(caption,label,headers,rows,wide=False,note='',size='footnotesize',gap='3pt'):
    env='table*' if wide else 'table'
    body=[rf'\begin{{{env}}}[t]',r'\centering',rf'\caption{{{caption}}}',rf'\label{{{label}}}',rf'\{size}',rf'\setlength{{\tabcolsep}}{{{gap}}}',r'\renewcommand{\arraystretch}{1.12}',r'\begin{tabular}{l'+'c'*(len(headers)-1)+'}',r'\toprule',line(headers),r'\midrule']
    body += [r'\midrule' if row is None else line(row) for row in rows]
    body += [r'\bottomrule',r'\end{tabular}']
    if note:body += [r'\par\smallskip',r'\begin{minipage}{\linewidth}',r'\scriptsize '+note,r'\end{minipage}']
    body += [rf'\end{{{env}}}']
    return '\n'.join(body)
def cell(x,best=False,sign=True,dagger=False):
    _,_,sg,mean,sd=parse(x)
    top=(r'\mathbf{'+mean+'}') if best else mean
    marks=(sg or '') if sign else ''
    if dagger:marks+=r'\dagger'
    if marks:top+='^{'+marks+'}'
    return r'\shortstack{$'+top+r'$\\$('+sd+')$}'
subs={}
subs['SETTINGS']=table('Experimental settings of the retained result sets. A dash denotes unverified or unavailable metadata.','tab:exp:settings',
 ['Result set','$M$','$D$','$N$','$FE_{\max}$','Runs/config.'],[
 ['Main comparison','10, 20','30 (31)','100','300','--'],
 ['Additional full suite','3, 5','10','--','--','--'],
 ['Additional full suite','8','10 (11)','100','300','--'],
 ['WFG-only comparison','12','30 (31)','100','300','--'],
 ['Two-module ablation','10, 20','30 (31)','100','300','--'],
 ['Snapshot/group audit','10, 20','30 (31)','100','500','5/behaviour'],
 ['Good-group precision','10, 20','30 (31)','100','500','25'],
 ['Candidate-value probe','20','30 (31)','100','300','10/policy']],True,
 note='Parenthesised decision dimensions apply to WFG3. The snapshot audit has two behaviours per configuration; the candidate probe has five policies. The good-group precision results cover the original five-problem study. Spreadsheet run counts are intentionally left unfilled.')
for m in [10,20]:
    h,rr=sheet(f'最新版算法总实验\\{m}目标.xlsx')
    alg=h[5:];target=alg[-1]
    rows=[]
    for r in rr:
        assert r['M']==m and r['N']==100 and r['FE']==300
        best=min(parse(r[a])[0] for a in alg)
        rows.append([r['Problem']]+[cell(r[a],parse(r[a])[0]==best,dagger=(m==10 and r['Problem']=='DTLZ1' and a in ['KRVEA','PCSAEA'])) for a in alg])
    counts=[]
    for a in alg[:-1]:
        c=Counter(parse(r[a])[2] for r in rr)
        assert sum(c.values())==16
        counts.append(f"{c['-']}/{c['=']}/{c['+']}")
    rows += [None,['W/T/L']+counts+['--']]
    headers=['Problem']+[a.replace('HES_EA','HES-EA') for a in alg[:-1]]+['HPDC-MaOEA']
    note='Each cell contains the exported mean IGD and standard deviation on separate lines. Symbols describe the comparator relative to HPDC-MaOEA; W/T/L describes HPDC-MaOEA relative to the comparator. Bold denotes the smallest mean.'
    if m==10:note+=r' $\dagger$: the two identical DTLZ1 entries are preserved from the source and require provenance verification.'
    subs[f'MAIN{m}']=table(f'IGD comparison on 16 {m}-objective problems with 300 evaluations.',f'tab:exp:main{m}',headers,rows,True,note,'scriptsize','3pt')
rows=[]
for m in [3,5,8,10,20,12]:
    _,rr=sheet(f'最新版算法总实验\\{m}目标.xlsx')
    a=['REMO','PIEA','MCEAD','KRVEA'];target=next(x for x in rr[0] if x and x.endswith('UniformMix_Original'))
    c=Counter(parse(r[x])[2] for r in rr for x in a)
    effects=[100*(parse(r[x])[0]-parse(r[target])[0])/parse(r[x])[0] for r in rr for x in a]
    if m==12:rows.append(None)
    rows.append([m,len(rr),f"{c['-']}/{c['=']}/{c['+']}",f"{100*c['-']/sum(c.values()):.1f}\\%",f'{np.median(effects):.2f}\\%'])
subs['OBJECTIVES']=table('Common-baseline comparisons across objective counts.','tab:exp:objectives',['$M$','Problems','W/T/L','Win fraction','Median reduction'],rows,note='REMO, PIEA, MCEAD and KRVEA are included in every row. The $M=12$ row covers WFG1--WFG9 only. Settings and verification notes follow Tables~\\ref{tab:exp:settings}--\\ref{tab:exp:main20}.',size='scriptsize',gap='2.5pt')
for m in [10,20]:
    k=15 if m==10 else 30
    h,rr=sheet(f'消融实验\\两个模块的消融实验\\full_{m}.xlsx')
    alg=['REMO',f'REMO (k={k})','REMO+HPC',f'REMO+HPC (k={k})','REMO+candidate',f'full (k={k})']
    valid=[r for r in rr if r['M']==m]
    _,main=sheet(f'最新版算法总实验\\{m}目标.xlsx')
    mainmap={r['Problem']:r for r in main}
    rows=[]
    for r in rr:
        if r['M']!=m:
            rows.append([r['Problem']]+['--']*len(alg));continue
        assert parse(r[alg[-1]])[:2]==parse(mainmap[r['Problem']]['REMO_new2_AdaMaO_SDEOnly_UniformMix_Original'])[:2]
        best=min(parse(r[a])[0] for a in alg)
        rows.append([r['Problem']]+[cell(r[a],parse(r[a])[0]==best) for a in alg])
    counts=[]
    for a in alg[:-1]:
        c=Counter(parse(r[a])[2] for r in valid)
        counts.append(f"{c['-']}/{c['=']}/{c['+']}")
    rows += [None,['W/T/L']+counts+['--'],['Best mean']+[sum(parse(r[a])[0]==min(parse(r[x])[0] for x in alg) for r in valid) for a in alg]]
    headers=['Problem',r'\shortstack{REMO\\$k=6$}',rf'\shortstack{{REMO\\$k={k}$}}',r'\shortstack{REMO+HPC\\$k=6$}',rf'\shortstack{{REMO+HPC\\$k={k}$}}',r'\shortstack{REMO+candidate\\$k=6$}',rf'\shortstack{{HPDC-MaOEA\\$k={k}$}}']
    note='Cells report mean IGD (standard deviation). Symbols and W/T/L follow the main tables. HPC denotes hybrid PBI grouping. The enlarged-$k$ HPC-only configuration isolates addition of candidate selection when compared with the full method.'
    if m==20:note+=' WFG4 is unfilled because the source row records $M=10$; all counts use the remaining 15 problems.'
    subs[f'ABL{m}']=table(f'Module ablation at $M={m}$ and 300 evaluations.',f'tab:exp:abl{m}',headers,rows,True,note,'scriptsize','4pt')
ggp=repo/'REMO_new2_AdaMaO_GoodGroupPrecision'
g=pd.read_csv(ggp/'results/analysis/formal/GGP_PerRunStage.csv')
g=g[(g.Truth=='population_final') & (g.SelectionRule=='top25')]
views=['score_hybrid','score_v','anchor_margin']
group=g.groupby(['Stage','View']).MeanPrecision.mean().unstack()
rows=[]
for stage,values in group.iterrows():
    lab={'S1_[0,0.25]':'$[0,0.25]$','S2_(0.25,0.50]':'$(0.25,0.50]$','S3_(0.50,0.75]':'$(0.50,0.75]$','S4_(0.75,1.00]':'$(0.75,1.00]$'}[stage]
    rows.append([lab]+[f'{values[v]:.5f}' for v in views])
rows += [None,['All stages']+[f'{g[g.View==v].MeanPrecision.mean():.5f}' for v in views]]
subs['PRECISION']=table('Precision@25\% for final-population retention.','tab:exp:precision',['$FE/FE_{\max}$','Hybrid','Direction','Margin'],rows,note='Each stage averages 250 run-level values per view. The last row gives equal weight to the four stages. Larger values mean a greater fraction of selected solutions remained in the final population.',size='footnotesize',gap='3pt')
cvp=pd.read_csv(repo/'REMO_new2_AdaMaO_CandidateValueProbe/docs/data/runs.csv')
arms=['V0_REMO_RULE','V1_POOL_ONLY','V2_EXPLORE_ONLY','V3_INDICATOR_ONLY','V4_FULL']
rows=[]
for problem in ['DTLZ2','DTLZ7','WFG3','WFG7']:
    q=cvp[cvp.Problem==problem];means=q.groupby('Arm').IGD.mean();sd=q.groupby('Arm').IGD.std()
    rows.append([problem]+[cell(f'{means[a]:.4e} ({sd[a]:.2e})',means[a]==means.min(),False) for a in arms])
rows.append(None)
for label,key in [('Mean batch size','BatchSizeMean'),('Mean batch spread','BatchSpreadMean'),('Late retention','SurvivalRateLate'),('Late gain ratio','OracleGainRatioLate')]:
    means=cvp.groupby('Arm')[key].mean()
    rows.append([label]+[f'{means[a]:.3f}' for a in arms])
subs['CANDIDATE']=table('Candidate-value probe at $M=20$: final IGD and batch properties.','tab:exp:candidate',['Problem / metric','V0: REMO rule','V1: relation top-six','V2: exploration','V3: indicator','V4: dual mode'],rows,True,'IGD entries are means (sample standard deviations) over ten runs per problem and policy. Batch statistics are equally averaged across the 40 runs of each policy. Only retention and gain ratio use the late-stage restriction. The V0 rule uses the probe host, and the greedy-reference diagnostic is restricted to the sampled pool.',size='scriptsize',gap='4pt')
rows=[]
for sub,m,metric in [('',10,'IGD'),('二十目标\\',20,'IGD'),('IGDp\\',20,'IGD$^+$')]:
    _,rr=sheet(f'消融实验\\候选解模块\\{sub}Ada_Mao_SDEonly_UniformMix.xlsx')
    for name,suffix in [('Exploration-only','AlwaysExplore'),('Indicator-only','AlwaysIndicator'),('Linear switching','LinearSchedule')]:
        a='REMO_new2_AdaMaO_SDEOnly_'+suffix
        c=Counter(parse(r[a])[2] for r in rr)
        rows.append([m,metric,name,f"{c['-']}/{c['=']}/{c['+']}"])
    if sub!='IGDp\\':rows.append(None)
subs['ROUTING']=table('Equal-probability switching versus alternative routing policies in the routing-study host.','tab:exp:routing',['$M$','Indicator','Comparator','W/T/L'],rows,note='Counts use all 16 problems and the exported annotations relative to UniformMix. These are separate host-specific comparisons; they are not ablations of the UniformMix\_Original entries in the main tables.',size='scriptsize',gap='3pt')
section=(work/'section.tex').read_text(encoding='utf-8')
for key,val in subs.items():
    assert section.count('@'+key+'@')==1,key
    section=section.replace('@'+key+'@',val)
assert not re.search('@[A-Z0-9]+@',section)
section=section.replace("Batch spread was measured by the probe's decision-space dispersion\nstatistic.","Batch spread was the mean pairwise Euclidean distance between selected\ncandidates after scaling each decision variable by its bounds.")
old=paper.read_bytes()
start=old.index(b'\\section{Experimental Studies}')
end=old.index(b'\\section{Conclusion}',start)
nl=b'\r\n' if b'\r\n' in old else b'\n'
newsection=section.replace('\r\n','\n').encode('utf-8').replace(b'\n',nl)+nl
new=old[:start]+newsection+old[end:]
paper.write_bytes(new)
assert new[:start]==old[:start]
assert new[new.index(b'\\section{Conclusion}'):]==old[end:]
(work/'rendered_section.tex').write_text(section,encoding='utf-8')
print('Updated experiment section only; prefix and conclusion/bibliography unchanged byte-for-byte.')
print('Tables:',section.count('\\caption{'),'Prose+table words:',len(section.split()))
