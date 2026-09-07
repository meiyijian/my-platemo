from pathlib import Path
import json
import hashlib
import numpy as np
import pandas as pd

ROOT = Path(r'D:\PlatEMO-master\PlatEMO-master\PlatEMO\Experiments\REMO_new2_AdaMaO_GoodGroupPrecision')
SRC = ROOT / 'results/analysis/formal'
OUT = SRC / 'expansion_audit_20260906'
OUT.mkdir(exist_ok=True)
NEW = ['DTLZ3', 'DTLZ5', 'DTLZ6', 'WFG1', 'WFG8']
d = pd.read_csv(SRC / 'GGP_PerRunStage.csv')
c = pd.read_csv(SRC / 'GGP_PairedComparisons.csv')
cov = pd.read_csv(SRC / 'GGP_Coverage.csv')
assert len(cov) == 20 and (cov.ObservedRuns == 25).all() and cov.Complete.all()
assert len(list((ROOT / 'results/raw/formal').rglob('run_*.mat'))) == 500
keys = ['Problem','M','Run','Stage','View','Truth']
assert not d.duplicated(keys).any()
assert d.groupby(['Problem','M']).Run.nunique().eq(25).all()
for frame in [d, c]:
    frame['Batch'] = np.where(frame.Problem.isin(NEW), 'new', 'old')
    frame['StageShort'] = frame.Stage.str[:2]
q = d[d.SelectionRule == 'top25'].copy()
metrics = ['MeanPrecision','MeanAUC','MeanChance','MeanLift','MeanRecall']

# Existing test rows must agree with the independent run-stage table.
g = q.groupby(['Problem','M','Stage','Truth','View'])
for row in c.itertuples():
    field = 'Mean' + row.Metric
    a = g.get_group((row.Problem,row.M,row.Stage,row.Truth,row.ViewA)).set_index('Run')[field]
    b = g.get_group((row.Problem,row.M,row.Stage,row.Truth,row.ViewB)).set_index('Run')[field]
    pair = pd.concat([a,b],axis=1).dropna()
    assert len(pair) == row.ValidPairs
    if len(pair):
        assert np.allclose([pair.iloc[:,0].mean(),pair.iloc[:,1].mean(),(pair.iloc[:,0]-pair.iloc[:,1]).mean()],
                           [row.MeanA,row.MeanB,row.MeanDelta],atol=1e-12)
for _, family in c.groupby(['Problem','M','Truth','Metric']):
    p = family.PValueRaw.dropna().sort_values()
    adjusted = np.minimum(1, np.maximum.accumulate(p.to_numpy() * np.arange(len(p),0,-1)))
    assert np.allclose(adjusted,c.loc[p.index,'PValueHolm'],atol=1e-12)

batch = q.groupby(['Batch','Truth','View'])[metrics].mean()
all_summary = q.groupby(['Truth','View'])[metrics].mean()
problem = q.groupby(['Problem','Truth','View'])[metrics].mean()
stages = q.groupby(['Batch','StageShort','Truth','View'])[metrics].mean()
cells = q.groupby(['Batch','Problem','M','StageShort','Truth','View'])[metrics].mean()
for name,table in [('batch_summary',batch),('all_summary',all_summary),('problem_summary',problem),('stage_summary',stages),('cell_summary',cells)]:
    table.to_csv(OUT / (name+'.csv'),encoding='utf-8-sig')

h = c[(c.ViewA == 'score_hybrid') & (c.ValidPairs > 0)].copy()
h['Outcome'] = np.where(h.RejectHolm05 & (h.MeanDelta > 0),'win',
                np.where(h.RejectHolm05 & (h.MeanDelta < 0),'loss','nonsignificant'))
wins = h.groupby(['Batch','Truth','Metric','ViewB','Outcome']).size().unstack(fill_value=0)
wins.to_csv(OUT/'holm_counts.csv',encoding='utf-8-sig')

print('BATCH population_final\n',batch.xs('population_final',level='Truth').round(6).to_string())
print('PROBLEM population_final\n',problem.xs('population_final',level='Truth').round(6).to_string())
print('STAGES population_final\n',stages.xs('population_final',level='Truth').round(6).to_string())
print('HOLM population_final\n',wins.xs('population_final',level='Truth').to_string())
print('ALL population_final\n',all_summary.loc['population_final'].round(6).to_string())

pc = cells.xs('population_final',level='Truth').reset_index()
wide = pc.pivot(index=['Batch','Problem','M','StageShort'],columns='View',values='MeanPrecision')
wide['DeltaV'] = wide.score_hybrid-wide.score_v
wide['DeltaAnchor'] = wide.score_hybrid-wide.anchor_margin
wide['DeltaBest'] = wide.score_hybrid-wide[['score_v','anchor_margin']].max(axis=1)
wide.to_csv(OUT/'precision_cell_deltas.csv',encoding='utf-8-sig')
print('TOP NEW CELLS against stronger baseline\n',wide.loc['new'].sort_values('DeltaBest',ascending=False).head(12).round(6).to_string())
print('LOW NEW CELLS against stronger baseline\n',wide.loc['new'].sort_values('DeltaBest').head(8).round(6).to_string())
print('NEW BOTH-SIGNIFICANT WINS population_final')
hh=h[(h.Batch=='new') & (h.Truth=='population_final')]
for metric in ['Precision','AUC','Lift']:
    p=hh[hh.Metric==metric].pivot(index=['Problem','M','StageShort'],columns='ViewB',values='Outcome')
    both=p[(p=='win').all(axis=1)]
    print(metric,len(both),both.index.tolist())
print('AUC missing by batch/truth',q.groupby(['Batch','Truth','View']).MeanAUC.apply(lambda x: x.isna().sum()).to_string())

# Audit checkpoint arithmetic and censoring without re-running optimization.
cp = pd.read_csv(SRC/'GGP_CheckpointMetrics.csv')
cp = cp[cp.SelectionRule == 'top25'].copy()
assert cp.PopulationSize.eq(100).all() and cp.SelectedCount.eq(25).all()
assert np.allclose(cp.Precision,cp.TruePositiveCount/cp.SelectedCount,equal_nan=True)
assert np.allclose(cp.Chance,cp.TruthPositiveCount/cp.PopulationSize,equal_nan=True)
mask=cp.Chance.gt(0)
assert np.allclose(cp.loc[mask,'Lift'],cp.loc[mask,'Precision']/cp.loc[mask,'Chance'],equal_nan=True)
assert np.allclose(cp.loc[mask,'Recall'],cp.loc[mask,'Lift']*.25,equal_nan=True)
assert cp.loc[cp.Censored.eq(1),['Precision','Chance','Lift','AUC']].isna().all().all()
cp['Batch']=np.where(cp.Problem.isin(NEW),'new','old')
cp['StageShort']=cp.Stage.str[:2]
cp['OraclePrecision']=np.minimum(1,cp.TruthPositiveCount/cp.SelectedCount)
cp['ExcessOverChance']=cp.Precision-cp.Chance
cp['OracleHeadroom']=cp.OraclePrecision-cp.Precision
aggkeys=['Batch','Problem','M','Run','StageShort','Truth','View']
r=cp.groupby(aggkeys)[['OraclePrecision','ExcessOverChance','OracleHeadroom']].mean().reset_index()
oracle=r.groupby(['Batch','StageShort','Truth','View'])[['OraclePrecision','ExcessOverChance','OracleHeadroom']].mean()
oracle.to_csv(OUT/'oracle_stage_summary.csv',encoding='utf-8-sig')
print('ORACLE population_final hybrid\n',oracle.xs(('population_final','score_hybrid'),level=('Truth','View')).round(6).to_string())
print('selected per-cell examples')
examples=[('DTLZ3',20,'S3'),('DTLZ4',20,'S3'),('DTLZ5',20,'S3'),('DTLZ6',20,'S3'),('WFG8',20,'S3')]
for prob,m,s in examples:
    print(c[(c.Problem==prob)&(c.M==m)&(c.StageShort==s)&(c.Truth=='population_final')&(c.ViewA=='score_hybrid')][['Problem','M','StageShort','Metric','ViewB','MeanA','MeanB','MeanDelta','PValueHolm','RankBiserial']].round(8).to_string(index=False))

meta = {'status':'ANALYZED; CSV arithmetic/aggregation/Holm recomputation verified; no optimization rerun',
        'n_runs':500,'n_per_configuration':25,'new_problems':NEW,'averaging':'checkpoint within run-stage, then equal run-stage macro averages',
        'numpy':np.__version__,'pandas':pd.__version__,
        'source_files':{f.name:{'sha256':hashlib.sha256(f.read_bytes()).hexdigest(),'bytes':f.stat().st_size} for f in SRC.glob('GGP_*.csv')}}
(OUT/'provenance.json').write_text(json.dumps(meta,ensure_ascii=False,indent=2),encoding='utf-8')

# Resample the 25 independent paired runs; repeated checkpoints are already averaged.
# Exploratory percentile intervals, not multiplicity-adjusted confidence intervals.
rng=np.random.default_rng(20260906)
bootrows=[]
for prob,m,s in [('DTLZ3',20,'S3'),('DTLZ4',20,'S3')]:
    sub=q[(q.Problem==prob)&(q.M==m)&(q.StageShort==s)&(q.Truth=='population_final')]
    print('EXAMPLE full metrics',prob,m,s,'\n',sub.groupby('View')[metrics].mean().round(8).to_string())
    for metric in ['Precision','AUC','Lift']:
        w=sub.pivot(index='Run',columns='View',values='Mean'+metric)
        for base in ['score_v','anchor_margin']:
            diff=(w.score_hybrid-w[base]).dropna().to_numpy()
            sample=diff[rng.integers(0,len(diff),size=(20000,len(diff)))].mean(axis=1)
            lo,hi=np.quantile(sample,[.025,.975])
            bootrows.append(dict(Problem=prob,M=m,Stage=s,Metric=metric,Baseline=base,N=len(diff),
                                 Delta=diff.mean(),Low95=lo,High95=hi,ExtraPositivePer25=25*diff.mean() if metric=='Precision' else np.nan))
boot=pd.DataFrame(bootrows)
boot.to_csv(OUT/'example_paired_bootstrap.csv',index=False,encoding='utf-8-sig')
print('EXPLORATORY BOOTSTRAP\n',boot.round(8).to_string(index=False))

# Confirm existing per-run arithmetic against checkpoint rows for all Top-25% metrics.
checkfields=['Precision','Recall','Chance','Lift','AUC']
cg=cp.groupby(keys)[checkfields].mean().rename(columns=lambda x:'Mean'+x).sort_index()
dg=q.set_index(keys)[['Mean'+x for x in checkfields]].sort_index()
assert cg.index.equals(dg.index)
assert np.allclose(cg.to_numpy(),dg.to_numpy(),equal_nan=True,atol=1e-12)
print('AUDIT_PASS: coverage, identities, checkpoint arithmetic, all per-run aggregates, all paired means, all Holm families')
