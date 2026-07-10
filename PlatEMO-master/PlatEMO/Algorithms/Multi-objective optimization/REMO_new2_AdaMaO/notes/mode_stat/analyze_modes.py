import pandas as pd
import numpy as np

df = pd.read_csv(r'D:\PlatEMO-master\PlatEMO-master\PlatEMO\Algorithms\Multi-objective optimization\REMO_new2_AdaMaO\notes\mode_distribution.csv')

print("="*60)
print(" 数据概览")
print("="*60)
print(f"总运行数: {len(df)}")
print(f"问题 ({df['problem'].nunique()}): {list(df['problem'].unique())}")
print(f"M值: {sorted(df['M'].unique())}")
print(f"total_gen: 均{df['total_gen'].mean():.1f} | skip_gen总和: {df['skip_gen'].sum()} (全0=无跳过轮)")

rel_cols = ['rel_conservative_ratio','rel_curriculum_ratio','rel_weighted_ratio']
cand_cols = ['cand_conservative_ratio','cand_explore_ratio','cand_indicator_ratio']

print("\n"+"="*60)
print(" 发现1: curriculum 是否只在首代?")
print("="*60)
print(df['rel_curriculum_cnt'].describe().to_string())
print(f"\ncurriculum次数==1 的运行: {(df['rel_curriculum_cnt']==1).sum()}/{len(df)} ({(df['rel_curriculum_cnt']==1).mean()*100:.0f}%)")
print(f"curriculum次数>=2 的运行: {(df['rel_curriculum_cnt']>=2).sum()}/{len(df)}")
print(f"curriculum平均占比: {df['rel_curriculum_ratio'].mean()*100:.1f}%")

print("\n"+"="*60)
print(" 发现2: 按问题×M分组 平均模式占比")
print("="*60)
g = df.groupby(['problem','M'])[rel_cols+cand_cols].mean()
print(g.round(3).to_string())

print("\n"+"="*60)
print(" 发现3: 运行间标准差(稳定性)")
print("="*60)
gs = df.groupby(['problem','M'])[rel_cols+cand_cols].std()
print(gs.round(3).to_string())

print("\n"+"="*60)
print(" 发现4: M=20 候选解模式是否indicator一家独大")
print("="*60)
m20 = df[df.M==20]
print(f"M=20 indicator占比均值: {m20['cand_indicator_ratio'].mean()*100:.1f}%")
print(f"M=20 indicator=1(纯indicator)运行: {(m20['cand_indicator_ratio']==1).sum()}/{len(m20)}")
print(f"M=20 explore>0的运行: {(m20['cand_explore_ratio']>0).sum()}/{len(m20)}")
print(f"M=20 conservative>0的运行: {(m20['cand_conservative_ratio']>0).sum()}/{len(m20)}")

print("\n"+"="*60)
print(" 发现5: M=10 候选解模式按问题分布")
print("="*60)
m10 = df[df.M==10]
print(m10.groupby('problem')[cand_cols].mean().round(3).to_string())

print("\n"+"="*60)
print(" 发现6: weighted_ratio 运行间方差最大的组合(最不稳定)")
print("="*60)
print(gs['rel_weighted_ratio'].sort_values(ascending=False).head(5).round(3).to_string())
print("\ncand_indicator_ratio 方差最大的组合:")
print(gs['cand_indicator_ratio'].sort_values(ascending=False).head(5).round(3).to_string())

print("\n"+"="*60)
print(" 发现7: M=10 DTLZ 候选模式是否几乎全conservative")
print("="*60)
m10dtlz = m10[m10.problem.str.startswith('DTLZ')]
print(f"M=10 DTLZ conservative占比均值: {m10dtlz['cand_conservative_ratio'].mean()*100:.1f}%")
print(f"M=10 DTLZ explore=0的运行: {(m10dtlz['cand_explore_ratio']==0).sum()}/{len(m10dtlz)}")
print(f"M=10 DTLZ indicator=0的运行: {(m10dtlz['cand_indicator_ratio']==0).sum()}/{len(m10dtlz)}")
