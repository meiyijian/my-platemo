"""Read-only MAT audit and IGD comparisons for the four completed M10 cases."""
from pathlib import Path
from collections import Counter
import csv, json, hashlib, re, warnings
import numpy as np
from scipy.io import loadmat
from scipy.stats import mannwhitneyu, wilcoxon, rankdata

BASE=Path(r'C:/Users/lsx/Desktop/REMOandDREMO测试集/10目标/n30')
OUT=Path(__file__).resolve().parent/'comparison_20260915'
OUT.mkdir(exist_ok=True)
PREFIX='REMO_new2_AdaMaO_SDEOnly_UniformMix_'
ALGS={'Lambdat030':'REMO_UniformMix_Pruned_Weighted_Lambdat030',
      'Lambda020':PREFIX+'Pruned_Weighted_Lambda020',
      'Weighted':PREFIX+'Pruned_Weighted','Original':PREFIX+'Original',
      'Pruned':PREFIX+'Pruned','Weighted_Q080':PREFIX+'Pruned_Weighted_Q080',
      'REMO':'REMO','PIEA':'PIEA','CSEA':'CSEA','PC-SAEA':'PCSAEA_N100',
      'K-RVEA':'KRVEA_100','MCEA/D':'MCEAD'}
PROBS=['DTLZ2','DTLZ4','DTLZ5','DTLZ7']
records=[]; exclusions=[]; raw={}

def scalar(x):
    a=np.asarray(x).reshape(-1)
    return float(a[-1]) if a.size else np.nan

def dumpcsv(name,rows):
    if not rows:return
    with (OUT/name).open('w',encoding='utf-8-sig',newline='') as f:
        w=csv.DictWriter(f,fieldnames=list(rows[0]));w.writeheader();w.writerows(rows)

for label,name in ALGS.items():
 for prob in PROBS:
  for file in sorted((BASE/name).glob(f'{name}_{prob}_M10_D30_*.mat')):
   run=int(re.search(r'_(\d+)\.mat$',file.name)[1])
   if run>30:continue
   try:
    data=loadmat(file,simplify_cells=True,variable_names=['result','metric','metadata'])
    result=data['result']; met=data['metric']; meta=data.get('metadata',{})
    fes=np.asarray([scalar(x) for x in result[:,0]])
    igds=np.asarray(met['IGD'],dtype=float).reshape(-1)
    assert np.all(np.isfinite(igds)) and np.all(igds>=0),'invalid IGD'
    assert np.all(np.isfinite(fes)) and np.all(np.diff(fes)>=0),'invalid FE trajectory'
    assert len(igds)==len(fes),'trajectory lengths differ'
    assert fes[-1]>=300,'incomplete budget'
    assert fes[-1]<400,'outside budget audit window'
    assert label in ['REMO','CSEA'] or fes[-1]==300,'unexpected FE overshoot'
    expected={'algorithm':name,'problem':prob,'M':10,'D':30,'maxFE':300,'runId':run,'actualFE':fes[-1]}
    for k,v in expected.items():
     if k in meta:assert meta[k]==v,f'metadata mismatch {k}'
    pars=np.asarray(meta.get('parameters',[]),dtype=float).reshape(-1)
    if label in ['Lambdat030','Lambda020','Weighted'] and pars.size:
     exp=[3000,.5,.25,.7,6]+([.2] if label=='Lambda020' else [])
     assert np.array_equal(pars,exp),'parameter mismatch'
    diag=meta.get('diagnostics',{})
    if label=='Lambdat030':
     assert meta['lambdaT']==.3 and diag['minLambdaT']==.3 and diag['maxLambdaT']==.3,'not fixed .3'
     assert 19<=run<=28,'unexpected new run ID'
    rngstate=meta.get('rngBeforeSolve',{}).get('State',[])
    row={'algorithm':label,'problem':prob,'run':run,'IGD':float(igds[-1]),'FE':float(fes[-1]),
     'first_saved_FE':float(fes[0]),'metadata_present':bool(meta),'seed':meta.get('seed',''),
     'threads':meta.get('threads',''),'matlabVersion':meta.get('matlabVersion',''),
     'parameters':json.dumps(pars.tolist()),'started':meta.get('started',''),
     'runtime':scalar(met.get('runtime',np.nan)),
     'rng_sha256':hashlib.sha256(np.asarray(rngstate,dtype=np.uint32).tobytes()).hexdigest() if len(rngstate) else '',
     'lambda_min':diag.get('minLambdaT',''),'lambda_max':diag.get('maxLambdaT',''),
     'lambda_mean':diag.get('meanLambdaT',''),'explore_rounds':diag.get('exploreRounds',''),
     'indicator_rounds':diag.get('indicatorRounds',''),'set_changed_share':diag.get('setChangedShare',''),
     'mean_overlap':diag.get('meanOverlap',''),'file':str(file),'sha256':hashlib.sha256(file.read_bytes()).hexdigest()}
    records.append(row); raw[label,prob,run]={'FE':fes,'IGD':igds,'meta':meta}
   except Exception as e:exclusions.append({'file':str(file),'reason':str(e)})
dumpcsv('run_audit.csv',records);dumpcsv('excluded.csv',exclusions)
lookup={(a,p):[r for r in records if r['algorithm']==a and r['problem']==p] for a in ALGS for p in PROBS}
stats=[]
for (a,p),rr in lookup.items():
 if not rr:continue
 x=np.array([r['IGD'] for r in rr])
 stats.append({'algorithm':a,'problem':p,'n':len(x),'mean':float(x.mean()),'sd':float(x.std(ddof=1)),
 'median':float(np.median(x)),'min':float(x.min()),'max':float(x.max()),
 'FE_min':min(r['FE'] for r in rr),'FE_max':max(r['FE'] for r in rr),
 'overshoot_runs':sum(r['FE']>300 for r in rr),'metadata_runs':sum(r['metadata_present'] for r in rr),
 'run_ids':','.join(str(r['run']) for r in sorted(rr,key=lambda r:r['run']))})
dumpcsv('descriptive.csv',stats)

def holm(ps):
    ps=np.asarray(ps);order=np.argsort(ps);adj=np.empty(len(ps));adj[order]=np.minimum(1,np.maximum.accumulate(ps[order]*np.arange(len(ps),0,-1)));return adj

rng=np.random.default_rng(20260915)
contrasts=[]
for a in ALGS:
 if a=='Lambdat030':continue
 for p in PROBS:
  x=np.array([r['IGD'] for r in lookup['Lambdat030',p]]);y=np.array([r['IGD'] for r in lookup[a,p]])
  if not len(x) or not len(y):continue
  tied=len(np.unique(np.r_[x,y]))<len(x)+len(y)
  method='asymptotic' if tied else 'exact'
  test=mannwhitneyu(x,y,alternative='two-sided',method=method)
  bx=x[rng.integers(0,len(x),(10000,len(x)))].mean(axis=1); by=y[rng.integers(0,len(y),(10000,len(y)))].mean(axis=1)
  ci=np.quantile((bx/by-1)*100,[.025,.975])
  contrasts.append({'comparator':a,'problem':p,'n_new':len(x),'n_comparator':len(y),
    'mean_new':float(x.mean()),'mean_comparator':float(y.mean()),'change_pct':float((x.mean()/y.mean()-1)*100),
    'p':float(test.pvalue),'p_holm4':None,'p_holm_all':None,'test':method,
    'cliffs_delta_positive_new_better':float(np.sign(y[None,:]-x[:,None]).mean()),
    'bootstrap_ci_low_pct':float(ci[0]),'bootstrap_ci_high_pct':float(ci[1]),'outcome_raw':'','outcome_holm':''})
for a in ALGS:
 cc=[r for r in contrasts if r['comparator']==a]
 for r,pa in zip(cc,holm([x['p'] for x in cc])):
  r['p_holm4']=float(pa)
for r,pa in zip(contrasts,holm([x['p'] for x in contrasts])):
 r['p_holm_all']=float(pa)
 for key,pk in [('outcome_raw','p'),('outcome_holm','p_holm4')]:r[key]='T' if r[pk]>=.05 else ('W' if r['mean_new']<r['mean_comparator'] else 'L')
dumpcsv('comparisons.csv',contrasts)

# Secondary, seed-identified historical pairs; not a same-session randomized control.
paired=[]
for a in ['Lambda020','Weighted']:
 for p in PROBS:
  xn={r['run']:r for r in lookup['Lambdat030',p]};yn={r['run']:r for r in lookup[a,p]}
  pairs=[(xn[i],yn[i]) for i in sorted(xn.keys()&yn.keys()) if xn[i]['seed']!='' and xn[i]['seed']==yn[i]['seed']]
  if not pairs:continue
  x=np.array([v['IGD'] for v,w in pairs]);y=np.array([w['IGD'] for v,w in pairs]);d=x-y
  with warnings.catch_warnings():
   warnings.simplefilter('ignore');pw=wilcoxon(d,alternative='two-sided',method='auto').pvalue if np.any(d) else 1.
  bs=rng.integers(0,len(x),(10000,len(x)));ci=np.quantile((x[bs].mean(axis=1)/y[bs].mean(axis=1)-1)*100,[.025,.975])
  paired.append({'comparator':a,'problem':p,'n_pairs':len(pairs),'mean_new':float(x.mean()),'mean_comparator':float(y.mean()),'change_pct':float((x.mean()/y.mean()-1)*100),
   'new_better_runs':int(sum(d<0)),'new_worse_runs':int(sum(d>0)),'same_runs':int(sum(d==0)),
   'rng_state_match':sum(v['rng_sha256']!='' and v['rng_sha256']==w['rng_sha256'] for v,w in pairs),
   'threads_match_known':sum(v['threads']!='' and v['threads']==w['threads'] for v,w in pairs),
   'matlab_version_match':sum(v['matlabVersion']!='' and v['matlabVersion']==w['matlabVersion'] for v,w in pairs),
   'p_signed_rank':float(pw),'p_holm4':None,'paired_bootstrap_ci_low_pct':float(ci[0]),'paired_bootstrap_ci_high_pct':float(ci[1])})
for a in ['Lambda020','Weighted']:
 cc=[r for r in paired if r['comparator']==a]
 for r,pa in zip(cc,holm([x['p_signed_rank'] for x in cc])):r['p_holm4']=float(pa)
dumpcsv('seed_matched_secondary.csv',paired)

# Common observed FE checkpoints; no extrapolation or fabricated interpolation.
curves=[]
for a in ALGS:
 for p in PROBS:
  rr=[raw[a,p,r['run']] for r in lookup[a,p]]
  for fe in [120,150,200,250,300]:
   vals=[r['IGD'][np.flatnonzero(r['FE']<=fe)[-1]] for r in rr if np.any(r['FE']<=fe) and r['FE'][-1]>=fe]
   if vals:curves.append({'algorithm':a,'problem':p,'FE_checkpoint':fe,'n':len(vals),'mean_IGD':float(np.mean(vals)),'sd_IGD':float(np.std(vals,ddof=1))})
dumpcsv('trajectory_checkpoints.csv',curves)
summary={'included_runs':len(records),'excluded':exclusions,'coverage':stats,'contrasts':contrasts,'paired_secondary':paired,
 'same_session_control_files':len(list((BASE/ALGS['Lambdat030']/'control_in_session').glob('*.mat'))),
 'method':'Final saved IGD; two-sided Mann-Whitney (exact if no pooled ties); Holm across four problems per comparator, plus all-contrast sensitivity; historical seed-matched signed-rank secondary; 10000 percentile bootstrap resamples; no new optimization.'}
(OUT/'analysis.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2),encoding='utf-8')
print('INCLUDED',len(records),'EXCLUDED',len(exclusions))
for p in PROBS:
 print('\n',p)
 for r in stats:
  if r['problem']==p:print(r['algorithm'],r['n'],round(r['mean'],6),round(r['sd'],6),'FE',r['FE_min'],r['FE_max'])
print('\nCONTRASTS')
for r in contrasts:print(r['comparator'],r['problem'],round(r['change_pct'],2),round(r['p'],5),round(r['p_holm4'],5),r['outcome_holm'])
print('\nSECONDARY',json.dumps(paired,ensure_ascii=False))
