import h5py, numpy as np, pandas as pd, os, glob
ROOT="/sessions/bold-sleepy-wright/mnt/PlatEMO-master/PlatEMO-master/PlatEMO/Experiments/REMO_new2_AdaMaO_CandidateValueProbe/results/raw/formal"

def sca(f,path):
    try:
        v=f[path][()]
        return float(np.array(v).ravel()[0])
    except Exception: return np.nan

def cellvec(f,path):
    """generations/<field> is (1,n) of object refs -> scalars"""
    ds=f[path]
    out=[]
    for r in np.array(ds).ravel():
        try: out.append(float(np.array(f[r]).ravel()[0]))
        except Exception: out.append(np.nan)
    return np.array(out,float)

SUM=['SurvivalRateAll','SurvivalRateLate','SurvivalRatePooled','SurvivalRateEarly',
 'SurvivalRateStage1','SurvivalRateStage2','SurvivalRateStage3','SurvivalRateStage4',
 'OracleHitRate','OracleHitRateLate','OracleGainRatio','OracleGainRatioLate',
 'OracleAlgorithmGain','OracleOracleGain','OraclePoolConsidered','OracleSubsampledFraction',
 'OracleRowCount','BatchSizeMean','BatchSizeMin','BatchSizeMax','BatchSpreadMean',
 'PoolRawMean','PoolUniqueMean','LastRoundUniqueMean','SelectedFromLastRoundMean',
 'RetainedCountMean','GenerationCount','EvaluatedTotal','SurvivorTotal',
 'AggregationChangedFraction','IndicatorOperationalFraction','IndicatorAvailableFraction',
 'IndicatorModeFraction','ExploreModeFraction','LambdaTMean','PErrMean',
 'FallbackGenerationCount','TruncatedGenerationCount','LastRoundUniqueMean']
META=['M','Run','Seed','ActualD','MaxFE','CompletedFE','ProblemN','Gmax','KEff' ]

rows=[]; gens=[]
for p in sorted(glob.glob(ROOT+"/*/*/*/run_*.mat")):
    parts=p.split(os.sep); arm=parts[-4]; prob=parts[-3]; Mdir=parts[-2]
    run=int(parts[-1].split('_')[1].split('.')[0])
    with h5py.File(p,'r') as f:
        r=dict(Arm=arm,Problem=prob,M=int(Mdir[1:]),Run=run,
               IGD=sca(f,'IGD'),IGDp=sca(f,'IGDp'),
               FEWithinBudget=sca(f,'validation/FEWithinBudget'),
               HandleIdentity=sca(f,'validation/SurvivalTrackedByHandleIdentity'),
               Runtime=sca(f,'validation/AlgorithmRuntime'))
        for k in SUM: r[k]=sca(f,'summary/'+k)
        for k in ['M','Run','CompletedFE','MaxFE','ActualD','Gmax','ProblemN','PMix','QKeep','NMin','NMax','RGood','Lambda0','OracleEvery','OraclePoolLimit','OracleReferenceSize','SchemaVersion','ArmID']:
            r['meta_'+k]=sca(f,'metadata/'+k)
        rows.append(r)
        # generations
        G={}
        for k in ['Generation','BatchSize','SurvivalRate','SurvivorCount','Ratio','FEBefore','FEAfter',
                  'OracleHitRate','OracleGainRatio','OracleValid','OracleAlgorithmGain','OracleOracleGain',
                  'OraclePoolConsidered','OraclePoolTotal','PoolUniqueCount','PoolRawCount','Mode',
                  'UsedFallback','TruncatedBatch','IndicatorOperational','LambdaT','BatchSpreadNormalized',
                  'SelectedFromLastRound','RetainedCount','ArchiveOverN','KEff','PErr','LastRoundUniqueCount',
                  'AggregationChanged','AggregationEligible','FinalAggregationWeighted','RoundCount','SelectedK']:
            try: G[k]=cellvec(f,'generations/'+k)
            except Exception: pass
        n=len(G['Generation']); G['Arm']=[arm]*n; G['Problem']=[prob]*n; G['M']=[int(Mdir[1:])]*n; G['Run']=[run]*n
        gens.append(pd.DataFrame(G))
runs=pd.DataFrame(rows)
gdf=pd.concat(gens,ignore_index=True)
runs.to_csv('/sessions/bold-sleepy-wright/mnt/outputs/cvp/runs.csv',index=False)
gdf.to_csv('/sessions/bold-sleepy-wright/mnt/outputs/cvp/generations.csv',index=False)
print(runs.shape, gdf.shape)
print(runs.groupby(['Problem','Arm']).size().unstack())
