import sys
from pathlib import Path

import numpy as np
import pandas as pd

sys.stdout.reconfigure(encoding='utf-8')

# E1 效度检验分析：confidence 是否预测"分类正确性"
# 运行前提：已在 MATLAB 中执行 run_E1.m，results/ 下有两份 CSV

HERE = Path(__file__).parent
ds = pd.read_csv(HERE / 'results' / 'E1_summary.csv')
dl = pd.read_csv(HERE / 'results' / 'E1_solution_level.csv')

print("=" * 70)
print(" E1 效度检验：conf 对'分类正确'的判别力")
print(f" 快照数: {len(ds)}  |  逐解行数: {len(dl)}")
print("=" * 70)

print("\n--- A. 总体 AUC（判据：>0.6 有信息 / ~0.5 无效）---")
for col, name in [('auc_conv', '解级AUC(收敛真值)'), ('auc_hyb', '解级AUC(混合真值)'),
                  ('auc_pair_conv', '对级AUC(收敛真值)'), ('auc_pair_hyb', '对级AUC(混合真值)')]:
    v = ds[col].dropna()
    lo, hi = v.mean() - 1.96 * v.std() / np.sqrt(len(v)), v.mean() + 1.96 * v.std() / np.sqrt(len(v))
    print(f"  {name:18s}: mean={v.mean():.3f}  95%CI=[{lo:.3f},{hi:.3f}]  "
          f"<0.55占比={(v < 0.55).mean() * 100:.0f}%  >0.6占比={(v > 0.6).mean() * 100:.0f}%")

print("\n--- B. 按问题 x M 的解级 AUC（两种真值口径）---")
g = ds.groupby(['problem', 'M'])[['auc_conv', 'auc_hyb', 'auc_pair_conv', 'acc_conv', 'mean_conf']].mean()
print(g.round(3).to_string())

print("\n--- C. 按阶段的 AUC（早期随机 -> 后期收敛）---")
g = ds.groupby('stage')[['auc_conv', 'auc_hyb', 'auc_pair_conv', 'acc_conv']].mean()
print(g.round(3).to_string())

print("\n--- D. 正确解 vs 错误解的 conf 分布（直观差距）---")
for tag, ccol in [('收敛真值', 'correct_conv'), ('混合真值', 'correct_hyb')]:
    c1 = dl[dl[ccol] == 1]['conf']
    c0 = dl[dl[ccol] == 0]['conf']
    print(f"  {tag}: 正确解 conf 均={c1.mean():.3f}(n={len(c1)})  "
          f"错误解 conf 均={c0.mean():.3f}(n={len(c0)})  差距={c1.mean() - c0.mean():+.3f}")

print("\n--- E. 分好/坏预测类看 conf 与正确性（检查语义混淆的方向性）---")
# 结构性疑点：标 0(坏) 的解 conf 自动高、标 1(好) 的解 conf 自动低。
# 若 conf 的"判别力"只是这种机械偏置，分类内 AUC 会比总体 AUC 低得多。
for cat, catname in [(True, '预测为好(Catalog=1)'), (False, '预测为坏(Catalog=0)')]:
    sub = dl[dl.catalog == cat]
    # 组内 AUC：按快照算再平均
    aucs = []
    for _, sg in sub.groupby(['problem', 'M', 'run', 'stage']):
        pos = sg[sg.correct_conv == 1]['conf'].values
        neg = sg[sg.correct_conv == 0]['conf'].values
        if len(pos) == 0 or len(neg) == 0:
            continue
        r = pd.Series(np.concatenate([pos, neg])).rank().values
        aucs.append((r[:len(pos)].sum() - len(pos) * (len(pos) + 1) / 2) / (len(pos) * len(neg)))
    print(f"  {catname}: 组内AUC均={np.mean(aucs):.3f} (n组={len(aucs)}) "
          f"conf均={sub['conf'].mean():.3f} 正确率={sub['correct_conv'].mean() * 100:.0f}%")

print("\n--- F. 判定 ---")
a = ds['auc_conv'].mean()
b = ds['auc_hyb'].mean()
p = ds['auc_pair_conv'].mean()
overall = np.mean([a, b, p])
if overall > 0.6:
    verdict = "conf 有信息（AUC>0.6）：问题主要在阈值放置，走 E4 阈值重设计路线"
elif overall > 0.55:
    verdict = "conf 弱有效（0.55<AUC<0.6）：信息量有限，建议度量改良 + 阈值重设计并行"
else:
    verdict = "conf 无效（AUC≈0.5）：度量必须重设计（归一化 PBI + 校准），跳过对旧度量的消融"
print(f"  解级AUC(conv)={a:.3f}  解级AUC(hyb)={b:.3f}  对级AUC(conv)={p:.3f}")
print(f"  >>> {verdict}")
