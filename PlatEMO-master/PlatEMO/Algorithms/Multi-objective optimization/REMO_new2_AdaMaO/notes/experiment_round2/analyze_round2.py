import pandas as pd
import numpy as np

R2_DIR = r'D:\PlatEMO-master\PlatEMO-master\PlatEMO\Algorithms\Multi-objective optimization\REMO_new2_AdaMaO\notes\experiment_round2'
R1_MODE = r'D:\PlatEMO-master\PlatEMO-master\PlatEMO\Algorithms\Multi-objective optimization\REMO_new2_AdaMaO\notes\mode_distribution.csv'

dm = pd.read_csv(R2_DIR + r'\mode_distribution_r2.csv')   # 第二轮模式 160行
dd = pd.read_csv(R2_DIR + r'\diagnostics_r2.csv')         # 第二轮诊断 ~5440行
d1 = pd.read_csv(R1_MODE)                                  # 第一轮模式 48行

rel_cols = ['rel_conservative_ratio','rel_curriculum_ratio','rel_weighted_ratio']
cand_cols = ['cand_conservative_ratio','cand_explore_ratio','cand_indicator_ratio']

print("="*70)
print(" 数据概览")
print("="*70)
print(f"第二轮: {len(dm)}运行, 诊断{len(dd)}行代")
print(f"第一轮: {len(d1)}运行")
print(f"问题: {sorted(dm['problem'].unique())}")
print(f"M: {sorted(dm['M'].unique())}")
print(f"每问题×M运行数: {dm.groupby(['problem','M']).size().iloc[0]}")
print(f"total_gen: 均{dm['total_gen'].mean():.1f}, skip_gen总和{dm['skip_gen'].sum()}")

print("\n"+"="*70)
print(" A. 模式分布10次统计 (均值±标准差)")
print("="*70)
g = dm.groupby(['problem','M'])[rel_cols+cand_cols]
gmean = g.mean().round(3)
gstd = g.std().round(3)
for (prob,m),row in gmean.iterrows():
    s = gstd.loc[(prob,m)]
    rv = row.values; sv = s.values
    print(f"{prob:6s} M{m:2d} | rel: cons {rv[0]:.2f}±{sv[0]:.2f} curr {rv[1]:.2f}±{sv[1]:.2f} weig {rv[2]:.2f}±{sv[2]:.2f} | cand: cons {rv[3]:.2f}±{sv[3]:.2f} expl {rv[4]:.2f}±{sv[4]:.2f} indi {rv[5]:.2f}±{sv[5]:.2f}")

print("\n"+"="*70)
print(" B. DTLZ7_M20 weighted 方差：第一轮 vs 第二轮（验证稳健性）")
print("="*70)
r1_dtlz7m20 = d1[(d1.problem=='DTLZ7')&(d1.M==20)]['rel_weighted_ratio']
r2_dtlz7m20 = dm[(dm.problem=='DTLZ7')&(dm.M==20)]['rel_weighted_ratio']
print(f"第一轮(3次): mean={r1_dtlz7m20.mean():.3f} std={r1_dtlz7m20.std():.3f} values={list(r1_dtlz7m20.round(2))}")
print(f"第二轮(10次): mean={r2_dtlz7m20.mean():.3f} std={r2_dtlz7m20.std():.3f}")
print(f"  95%CI: [{r2_dtlz7m20.mean()-1.96*r2_dtlz7m20.std()/np.sqrt(10):.3f}, {r2_dtlz7m20.mean()+1.96*r2_dtlz7m20.std()/np.sqrt(10):.3f}]")

print("\n"+"="*70)
print(" C. 假设1: DTLZ4/7 M=20 的 degeneracy 是否 <0.45 (解释explore)")
print("="*70)
for prob in ['DTLZ2','DTLZ4','DTLZ7','WFG3','WFG4','WFG6','WFG9']:
    for m in [10,20]:
        sub = dd[(dd.problem==prob)&(dd.M==m)]
        if len(sub)==0: continue
        deg = sub['degeneracy']
        print(f"{prob:6s} M{m:2d}: degeneracy mean={deg.mean():.3f} min={deg.min():.3f} max={deg.max():.3f} | <0.45占比={ (deg<0.45).mean()*100:.0f}%")

print("\n"+"="*70)
print(" D. 假设2: curriculum 触发时 p_err / prev_p_err")
print("="*70)
curr = dd[dd.relation_mode=='curriculum']
print(f"curriculum 代数: {len(curr)} / 总{len(dd)} ({len(curr)/len(dd)*100:.1f}%)")
print(f"  p_err: NaN数={curr['p_err'].isna().sum()}, 非NaN mean={curr['p_err'].mean(skipna=True):.3f}")
print(f"  prev_p_err: mean={curr['prev_p_err'].mean():.3f} (>0.35触发条件) min={curr['prev_p_err'].min():.3f}")
print(f"  prev_p_err>0.35 的占比: {(curr['prev_p_err']>0.35).mean()*100:.0f}%")
print(f"  curriculum 触发的gen分布:")
print(curr.groupby('gen').size().to_string())

print("\n"+"="*70)
print(" E. 假设3: weighted 触发时 coverage / prev_p_err / mean_conf")
print("="*70)
weig = dd[dd.relation_mode=='weighted']
print(f"weighted 代数: {len(weig)} / 总{len(dd)} ({len(weig)/len(dd)*100:.1f}%)")
print(f"  coverage: mean={weig['coverage'].mean():.3f} (<0.60触发) <0.60占比={(weig['coverage']<0.60).mean()*100:.0f}%")
print(f"  prev_p_err: mean={weig['prev_p_err'].mean():.3f} (<=0.35触发) <=0.35占比={(weig['prev_p_err']<=0.35).mean()*100:.0f}%")
print(f"  mean_conf: mean={weig['mean_conf'].mean():.3f} (>=0.55触发) >=0.55占比={(weig['mean_conf']>=0.55).mean()*100:.0f}%")

print("\n"+"="*70)
print(" F. 候选模式切换频率（每运行的cand_mode变化次数）")
print("="*70)
def nswitch(s):
    return (s != s.shift()).sum() - 1  # 减第一代
sw = dd.groupby(['problem','M','run_id'])['candidate_mode'].apply(nswitch)
print(f"每运行候选模式切换次数: mean={sw.mean():.1f} min={sw.min()} max={sw.max()}")
print(f"切换0次的运行占比: {(sw==0).mean()*100:.0f}%")
print(f"切换>=2次的运行占比: {(sw>=2).mean()*100:.0f}%")
print("\n按问题×M的平均切换次数:")
print(sw.groupby(['problem','M']).mean().round(1).to_string())

print("\n"+"="*70)
print(" G. p_err 时间趋势（训练后是否速降到0.35以下）")
print("="*70)
dd_clean = dd.dropna(subset=['p_err'])
for phase, gens in [('gen1', [1]), ('gen2-5', [2,3,4,5]), ('gen6-15', list(range(6,16))), ('gen16+', list(range(16,40)))]:
    sub = dd_clean[dd_clean.gen.isin(gens)]
    if len(sub)>0:
        print(f"  {phase:8s}: p_err mean={sub['p_err'].mean():.3f} <=0.35占比={(sub['p_err']<=0.35).mean()*100:.0f}%")

print("\n"+"="*70)
print(" H. degeneracy 与 M 的关系（M=10 vs M=20）")
print("="*70)
for m in [10,20]:
    sub = dd[dd.M==m]
    print(f"M={m}: degeneracy mean={sub['degeneracy'].mean():.3f} >=0.45占比={(sub['degeneracy']>=0.45).mean()*100:.0f}%")
print("  -> M=20 若普遍>=0.45，解释indicator主导；M=10 若普遍<0.45，解释explore主导")

print("\n"+"="*70)
print(" I. indicator 触发条件拆解（为何DTLZ4/7 M20没触发）")
print("="*70)
for prob in ['DTLZ4','DTLZ7']:
    sub = dd[(dd.problem==prob)&(dd.M==20)]
    print(f"{prob} M20:")
    print(f"  degeneracy>=0.45 占比: {(sub['degeneracy']>=0.45).mean()*100:.0f}%")
    print(f"  p_err<=0.35 占比: {(sub['p_err']<=0.35).mean()*100:.0f}%")
    print(f"  两条件同时满足占比: {((sub['degeneracy']>=0.45)&(sub['p_err']<=0.35)).mean()*100:.0f}% (这是indicator触发条件)")

print("\n"+"="*70)
print(" J. 每运行占比分布（双峰性检验：不稳健是双峰锁定，不是噪声）")
print("="*70)
v = dm[(dm.problem=='DTLZ7')&(dm.M==20)]['rel_weighted_ratio'].round(2).tolist()
print(f"DTLZ7_M20 rel_weighted 10次: {sorted(v)}")
v = dm[(dm.problem=='DTLZ1')&(dm.M==20)]['cand_indicator_ratio'].round(2).tolist()
print(f"DTLZ1_M20 cand_indicator 10次: {sorted(v)}")
v = dm[(dm.problem=='WFG4')&(dm.M==10)]['cand_indicator_ratio'].round(2).tolist()
print(f"WFG4_M10  cand_indicator 10次: {sorted(v)}")

print("\n"+"="*70)
print(" K. weighted 三条件的真实判别力（coverage/prev_p_err 是否恒满足）")
print("="*70)
for prob in sorted(dd['problem'].unique()):
    for m in [10,20]:
        sub = dd[(dd.problem==prob)&(dd.M==m)]
        if len(sub)==0: continue
        conf = sub['mean_conf']; cov = sub['coverage']
        print(f"{prob:6s} M{m:2d}: mean_conf 均={conf.mean():.3f} >=0.55占比={(conf>=0.55).mean()*100:3.0f}% | coverage 均={cov.mean():.3f} <0.60占比={(cov<0.60).mean()*100:3.0f}%")
print("-> coverage<0.60 处处100%满足=无判别力；relation_mode 实际由 mean_conf>=0.55 单条件决定")

print("\n"+"="*70)
print(" L. DTLZ7_M20 分运行 mean_conf（双峰根因：conf 骑在阈值0.55上）")
print("="*70)
sub = dd[(dd.problem=='DTLZ7')&(dd.M==20)]
g = sub.groupby('run_id').agg(conf_mean=('mean_conf','mean'),
                              conf_ge055=('mean_conf', lambda s:(s>=0.55).mean()),
                              weig=('relation_mode', lambda s:(s=='weighted').mean()))
print(g.round(3).to_string())

print("\n"+"="*70)
print(" M. 诊断量逐代动态（是否静态→解释模式锁定）")
print("="*70)
for prob in ['DTLZ1','DTLZ2','WFG4','WFG9']:
    for m in [10,20]:
        sub = dd[(dd.problem==prob)&(dd.M==m)]
        early = sub[sub.gen<=5]['degeneracy'].mean()
        late = sub[sub.gen>=30]['degeneracy'].mean()
        print(f"{prob:6s} M{m:2d}: degeneracy gen1-5={early:.3f} -> gen30+={late:.3f} (Δ={late-early:+.3f})")
for phase,gens in [('gen1-5',range(1,6)),('gen6-15',range(6,16)),('gen16+',range(16,40))]:
    sub = dd[dd.gen.isin(list(gens))]
    print(f"coverage {phase:8s}: mean={sub['coverage'].mean():.3f} max={sub['coverage'].max():.3f}")

print("\n"+"="*70)
print(" N. p_err 尖峰与后期 curriculum 的对应关系")
print("="*70)
spike = dd[dd['p_err']>0.35]
late_curr = dd[(dd.relation_mode=='curriculum')&(dd.gen>=3)]
print(f"p_err>0.35 尖峰: {len(spike)} 代；后期(gen>=3) curriculum: {len(late_curr)} 代")
print("尖峰的问题分布:");      print(spike.groupby(['problem','M']).size().to_string())
print("后期curriculum的问题分布:"); print(late_curr.groupby(['problem','M']).size().to_string())
print(f"-> 二者问题分布几乎一一对应：尖峰下一代触发curriculum，触发后 p_err 均值降至 {late_curr['p_err'].mean():.3f}")
