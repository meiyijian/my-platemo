from pathlib import Path
import pandas as pd
root=Path(r'D:\PlatEMO-master\PlatEMO-master\PlatEMO\Experiments')
ggp=root/'REMO_new2_AdaMaO_GoodGroupPrecision'
p=pd.read_csv(ggp/'results/analysis/formal/GGP_PerRunStage.csv')
p=p[(p.Truth=='population_final') & (p.SelectionRule=='top25')]
print('GGP',p.shape, p.groupby('View').MeanPrecision.mean().to_dict())
print(p.groupby(['Stage','View']).MeanPrecision.mean().unstack().to_string())
n=pd.read_csv(ggp/'results/analysis/formal/GGP_LabelDynNative.csv')
n=n[n.Truth=='population_final']
print('NATIVE',n[['MeanSelectedRate','MeanPrecision']].mean().to_dict())
print('BYPROBLEM',p.groupby(['Problem','View']).MeanPrecision.mean().unstack().to_string())
d=pd.read_csv(ggp/'DualPBI_Complementarity/results/analysis/formal/tables/GGP_ComplementarityDecision.csv')
print('DECISION',len(d),d[['FusionSupported','UniqueSupported']].sum().to_dict())
cvp=root/'REMO_new2_AdaMaO_CandidateValueProbe/docs/data'
r=pd.read_csv(cvp/'runs.csv')
assert len(r)==200 and r.groupby(['Problem','M','Arm']).size().eq(10).all()
assert r.meta_M.eq(20).all() and r.meta_CompletedFE.eq(300).all()
print('CVP',r.groupby('Arm')[['SurvivalRateLate','OracleGainRatioLate','BatchSpreadMean','BatchSizeMean']].mean().to_string())
print('IGDmean',r.groupby(['Problem','Arm']).IGD.mean().unstack().to_string())
print('IGDstd',r.groupby(['Problem','Arm']).IGD.std().unstack().to_string())
print('BATCHRANGE',r.groupby('Arm')[['BatchSizeMin','BatchSizeMax']].agg(['min','max']).to_string())
g=pd.read_csv(cvp/'generations.csv')
print('NONTRUNCATED',g[(g.Arm!='V0_REMO_RULE') & (g.TruncatedBatch==0)].BatchSize.value_counts().to_dict())
print('GGP STAGES',p.Stage.unique())
