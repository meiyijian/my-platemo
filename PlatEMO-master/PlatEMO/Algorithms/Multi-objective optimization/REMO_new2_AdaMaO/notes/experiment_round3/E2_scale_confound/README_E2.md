# E2：尺度混淆检验（confidence 是否被目标量纲污染）

> 创建：2026-07-11 ｜ 状态：**待运行**
> 上游：代码审查发现 `score_v = 1/(1+PBI)` 的 PBI 在未归一化目标空间计算
> 本实验回答：**conf 的跨问题差异是问题特性，还是量纲假象？**

## 一、实验目的

confidence 的两个成分对尺度的敏感性不同（代码事实，非猜测）：

- `label_dyn`（`GetOutput_PBI`）：内部把 g 除以 ‖Ref−Zmin‖ → **对均匀缩放不变**；
- `score_v`（`HybridPBI_Classification` 步骤三）：PBI 直接用原始目标值 → **随量纲缩放**。

因此把同一种群的目标整体乘 c（问题本质完全不变），conf 若漂移，
**责任唯一归于 score_v 未归一化**——这是一个干净的归因实验。

第二轮观察到 WFG4_M20 conf 高（0.639）、DTLZ2_M20 低（0.505），
两者与固定阈值 0.55 的相对位置决定了模式走向。若本实验证实量纲混淆，
则这种"问题间差异"部分是假象，`mean_conf>=0.55` 的跨问题固定阈值失去合法性。

## 二、预注册预测（实验前写下，避免事后合理化）

由 `conf_i = 1 - |score_v_i - label_i|`：

| 情形 | score_v | conf_i | mean_conf 极限 |
|---|---|---|---|
| c → 0 | → 1 | → label_i | → 好类标签占比 |
| c → ∞ | → 0 | → 1 − label_i | → 坏类标签占比 |

即 mean_conf 随 c **单调滑动**，两端极限由 `GetOutput_PBI` 的自适应好类比例
（约 0.3–0.7）决定；门控 `mean_conf>=0.55` 会被纯量纲操作翻转。

## 三、实验设计

- 快照与 E1 **完全相同**（同问题、同 seed=1..5、同 5 阶段），结果可互相印证；
- 对每个快照，构造 7 个目标值变体，各调一次原版 `HybridPBI_Classification`：

| 变体 | 操作 | 检验什么 |
|---|---|---|
| base | 原始目标 | 基准 |
| x0.1 / x10 / x100 | 整体乘 c | 均匀缩放不变性（理想度量应 Δ=0） |
| wfg_style | 第 j 目标乘 2j | 给 DTLZ 加上 WFG 式量纲 → 跨问题差异是否人造 |
| de_wfg | 第 j 目标除 2j | 把 WFG 式量纲拉平 |
| minmax | 各目标归一化 [0,1] | 候选修复方案的预演 |

- 指标（均相对 base）：Δmean_conf、门控翻转率、conf 排序 Spearman、
  好类集合 Jaccard（注意：score_hybrid 混合了 score_v，量纲甚至会改变**分类本身**）。

## 四、判据（预注册）

- |Δmean_conf| 均值 > 0.05 或 x100 门控翻转率 > 10% → **证实尺度混淆**：
  固定 0.55 跨问题阈值不可救，修复 = score_v 改用归一化目标 + 分位数/滞后阈值；
- 反之 → conf 差异主要来自问题特性，重点转向阈值放置（E4）。

minmax 变体如果表现稳定（组间 mean_conf 靠拢、排序保持），
就是"归一化 PBI"修复方案的直接证据。

## 五、如何运行

```matlab
% MATLAB（约 10–20 分钟）
cd 'D:\PlatEMO-master\PlatEMO-master\PlatEMO\Algorithms\Multi-objective optimization\REMO_new2_AdaMaO\notes\experiment_round3\E2_scale_confound'
run_E2               % 完整版
run_E2('n_run',2)    % 快速试跑
```

```bash
# 然后（命令行）
cd "D:\PlatEMO-master\PlatEMO-master\PlatEMO\Algorithms\Multi-objective optimization\REMO_new2_AdaMaO\notes\experiment_round3\E2_scale_confound"
py -3.13 -X utf8 analyze_E2.py
```

## 六、输出文件

| 文件 | 内容 |
|---|---|
| `results/E2_variants.csv` | 每快照×每变体一行（2800 行）：mean_conf、门控、Δ、Spearman、Jaccard |

## 七、已知局限

1. 快照为代理进化种群（同 E1 局限 1）；
2. `wfg_style`/`de_wfg` 的列缩放会真实改变 PBI 几何（余弦夹角），
   其结果解释为"量纲差异对跨问题可比性的影响"，而非纯不变性检验
   （纯不变性看 x0.1/x10/x100 三个均匀缩放变体即可）。
