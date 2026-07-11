import sys
from pathlib import Path

import numpy as np
import pandas as pd

sys.stdout.reconfigure(encoding='utf-8')

# E2 尺度混淆检验分析：confidence 是否被目标量纲污染
# 运行前提：已在 MATLAB 中执行 run_E2.m，results/ 下有 E2_variants.csv

HERE = Path(__file__).parent
df = pd.read_csv(HERE / 'results' / 'E2_variants.csv')
base = df[df.variant == 'base'].set_index(['problem', 'M', 'run', 'stage'])

print("=" * 70)
print(" E2 尺度混淆检验：同一种群，只改目标量纲，conf 变不变？")
print(f" 行数: {len(df)}  变体: {sorted(df.variant.unique())}")
print("=" * 70)

print("\n--- A. 均匀缩放下的 mean_conf 漂移（理想尺度不变度量：Δ=0）---")
print("  预注册预测: c->0 时 conf->好类占比, c->inf 时 conf->坏类占比, 单调滑动")
for v in ['x0.1', 'base', 'x10', 'x100']:
    sub = df[df.variant == v]
    print(f"  {v:6s}: mean_conf 均={sub['mean_conf'].mean():.3f}  "
          f"|Δ|均={sub['delta_mean_conf'].abs().mean():.3f}  "
          f"|Δ|max={sub['delta_mean_conf'].abs().max():.3f}")

print("\n--- B. 门控翻转率（mean_conf>=0.55 的判定是否被量纲改变）---")
for v in [x for x in df.variant.unique() if x != 'base']:
    sub = df[df.variant == v].set_index(['problem', 'M', 'run', 'stage'])
    joined = sub[['gate_weighted']].join(base[['gate_weighted']], rsuffix='_base')
    flip = (joined.gate_weighted != joined.gate_weighted_base).mean()
    print(f"  {v:10s}: 门控翻转率={flip * 100:5.1f}%")

print("\n--- C. conf 的排序稳定性（Spearman vs base，排序都保不住则加权语义已变）---")
g = df[df.variant != 'base'].groupby('variant')['spearman_vs_base'].agg(['mean', 'min'])
print(g.round(3).to_string())

print("\n--- D. 分类结果本身是否被量纲改变（好类集合 Jaccard vs base）---")
# score_hybrid = alpha*score_v + (1-alpha)*label，score_v 幅度变 => 混合权重实际改变
g = df[df.variant != 'base'].groupby('variant')['jaccard_vs_base'].agg(['mean', 'min'])
print(g.round(3).to_string())

print("\n--- E. 按问题看均匀缩放的漂移方向（验证'单调滑向标签占比'的预测）---")
pv = df[df.variant.isin(['x0.1', 'base', 'x10', 'x100'])].pivot_table(
    index=['problem', 'M'], columns='variant', values='mean_conf')
pv = pv[['x0.1', 'base', 'x10', 'x100']]
print(pv.round(3).to_string())

print("\n--- F. 跨问题可比性：wfg_style / de_wfg / minmax ---")
# 若 DTLZ 乘上 WFG 式量纲后 conf 明显变化，则第二轮观察到的
# "WFG4 conf 高、DTLZ2 conf 低"部分是量纲假象而非问题特性
for v in ['wfg_style', 'de_wfg', 'minmax']:
    sub = df[df.variant == v]
    print(f"  {v:10s}: Δmean_conf 均={sub['delta_mean_conf'].mean():+.3f}  "
          f"|Δ|均={sub['delta_mean_conf'].abs().mean():.3f}")
print("\n  minmax 归一化后，各问题组 mean_conf 是否互相靠拢（跨问题标准差）：")
for v in ['base', 'minmax']:
    gm = df[df.variant == v].groupby(['problem', 'M'])['mean_conf'].mean()
    print(f"    {v:6s}: 组间标准差={gm.std():.3f}  范围=[{gm.min():.3f}, {gm.max():.3f}]")

print("\n--- G. 判定 ---")
drift = df[df.variant.isin(['x0.1', 'x10', 'x100'])]['delta_mean_conf'].abs().mean()
sub100 = df[df.variant == 'x100'].set_index(['problem', 'M', 'run', 'stage'])
joined = sub100[['gate_weighted']].join(base[['gate_weighted']], rsuffix='_base')
flip100 = (joined.gate_weighted != joined.gate_weighted_base).mean()
if drift > 0.05 or flip100 > 0.1:
    print(f"  |Δmean_conf|均={drift:.3f}, x100门控翻转率={flip100 * 100:.0f}%")
    print("  >>> 证实尺度混淆：conf 随量纲漂移，固定 0.55 跨问题阈值不可救；")
    print("      修复方向 = score_v 用归一化目标计算（参考 minmax 变体的表现）+ 分位数/滞后阈值")
else:
    print(f"  |Δmean_conf|均={drift:.3f}, x100门控翻转率={flip100 * 100:.0f}%")
    print("  >>> 未见明显尺度混淆：conf 的跨问题差异主要来自问题特性，重点转向阈值放置")
