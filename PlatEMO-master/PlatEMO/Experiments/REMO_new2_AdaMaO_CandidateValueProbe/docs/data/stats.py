import pandas as pd,numpy as np
from scipy.stats import wilcoxon
pd.set_option('display.width',250); pd.set_option('display.max_columns',60)
r=pd.read_csv('runs.csv')
def cliffs(a,b):
    a=np.asarray(a);b=np.asarray(b);n=0
    for x in a: n+=np.sign(x-np.asarray(b)).sum()
    return n/(len(a)*len(b))
def holm(ps):
    ps=np.asarray(ps,float); o=np.argsort(ps); m=len(ps); adj=np.empty(m); run=0
    for i,idx in enumerate(o):
        run=max(run,(m-i)*ps[idx]); adj[idx]=min(1.0,run)
    return adj
rows=[]
for metric,better in [('IGD','lower'),('SurvivalRateLate','higher'),('SurvivalRatePooled','higher'),
                      ('OracleHitRateLate','higher'),('OracleGainRatioLate','higher')]:
    for base in ['V1_POOL_ONLY','V0_REMO_RULE']:
        for arm in ['V0_REMO_RULE','V1_POOL_ONLY','V2_EXPLORE_ONLY','V3_INDICATOR_ONLY','V4_FULL']:
            if arm==base: continue
            for prob in list(r.Problem.unique())+['ALL']:
                sub=r if prob=='ALL' else r[r.Problem==prob]
                A=sub[sub.Arm==arm].sort_values(['Problem','Run'])[metric].values
                B=sub[sub.Arm==base].sort_values(['Problem','Run'])[metric].values
                d=A-B
                if np.allclose(d,0): p=1.0
                else:
                    try: p=wilcoxon(A,B,zero_method='wilcox').pvalue
                    except Exception: p=np.nan
                sign = ('+' if (d.mean()<0)==(better=='lower') else '-')
                rows.append(dict(Metric=metric,Base=base,Arm=arm,Problem=prob,n=len(A),
                    ArmMean=A.mean(),BaseMean=B.mean(),MeanDiff=d.mean(),MedianDiff=np.median(d),
                    p_raw=p,Cliff=cliffs(A,B),FavorsArm=sign))
c=pd.DataFrame(rows)
c['p_holm']=np.nan
for (m,b),grp in c[c.Problem!='ALL'].groupby(['Metric','Base']):
    c.loc[grp.index,'p_holm']=holm(grp.p_raw.values)
c.to_csv('contrasts.csv',index=False)
def show(metric,base):
    s=c[(c.Metric==metric)&(c.Base==base)]
    print(f'--- {metric} vs {base} ---')
    print(s[['Arm','Problem','n','ArmMean','BaseMean','MeanDiff','p_raw','p_holm','Cliff','FavorsArm']].round(4).to_string(index=False))
    print()
show('IGD','V1_POOL_ONLY'); show('IGD','V0_REMO_RULE')
