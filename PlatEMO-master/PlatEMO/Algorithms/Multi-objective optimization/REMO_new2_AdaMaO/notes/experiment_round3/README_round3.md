# 第三轮实验：mean_conf 合理性验证（E1 效度 + E2 尺度混淆）

> 创建时间：2026-07-11
> 承接第二轮结论："weighted 的三条件实际退化为 `mean_conf >= 0.55` 单条件开关"。
> 本轮回答：**这个 mean_conf 本身靠不靠谱？**

## 研究背景（为什么做这两个实验）

第二轮实验（`../experiment_round2/`）发现 relation_mode 的判别力全部压在
`mean_conf >= 0.55` 一个条件上（coverage<0.60 恒真、prev_p_err<=0.35 近恒真），
且 0.55 恰好骑在半数问题组的 conf 分布中心（16 组中 8 组位于 P25–P75），
导致 DTLZ7_M20 等出现运行级双峰锁定。

代码审查（`HybridPBI_Classification.m`）发现 confidence 有三个结构性疑点：

1. **尺度依赖**：`score_v = 1/(1+PBI)` 的 PBI 在**未归一化的原始目标空间**计算，
   WFG 目标上限 2i（M=20 时达 40）、DTLZ2 只有 ~1.5，数值跨问题不可比；
2. **语义混淆**：`confidence = 1 - |score_v - label_dyn|`，label_dyn 是 0/1 二值、
   score_v 通常很小 → 标 0 的解 conf 自动高、标 1 的解 conf 自动低，
   mean_conf 数值上主要由"坏类比例 × 目标量纲"决定，与"分类是否正确"无必然联系；
3. **从未校准**：下游 `Ws = sqrt(conf_i*conf_j)` 加权训练的合法性建立在
   "conf 高 → 标签更可靠"这个从未验证过的假设上。

关键旁证（读代码所得，可作 E2 的预注册预测）：
`GetOutput_PBI` 内部把 g 除以 ‖Ref−Zmin‖（尺度不变），而 score_v 不归一化——
**若 conf 随均匀缩放漂移，责任唯一归于 score_v**。

## 两个实验

| 实验 | 问题 | 方法 | 预计耗时 |
|---|---|---|---|
| **E1** `E1_conf_validity/` | conf 是否真的预测"分类正确性"？ | 静态快照 + 真值对照，算 AUC | 全程离线，约 10–30 分钟 |
| **E2** `E2_scale_confound/` | conf 是否被目标尺度混淆？ | 同一种群目标缩放 c 倍 / 归一化后重算 conf | 全程离线，约 10–20 分钟 |

两个实验都**不跑完整 REMO 算法**（无模型训练），只做静态分类调用，成本极低。

## 判据与决策分支（预注册，避免事后合理化）

- **E1**：AUC > 0.6 → conf 有信息，问题只在阈值 → 后续做 E4（阈值重设计）；
  AUC ≈ 0.5 → conf 无效 → 直接重设计度量（归一化 PBI + 校准），跳过对旧度量的 E3 消融。
- **E2**：conf 随 c 单调漂移 / 归一化后排序大变 → 证实尺度混淆 →
  "固定 0.55 跨问题阈值"不可救，必须改归一化 PBI 或分位数阈值。

## 目录结构

```text
experiment_round3/
├── README_round3.md            ← 本文件（总览）
├── common/                     ← 两实验共享的工具函数
│   ├── gen_snapshots.m         ← 生成不同进化阶段的种群快照（代理进化）
│   ├── truth_labels.m          ← 用真实目标值构造"真值好类"（两种口径）
│   └── rank_auc.m              ← Mann-Whitney 秩 AUC
├── E1_conf_validity/           ← 实验一：conf 效度检验
│   ├── README_E1.md
│   ├── run_E1.m                ← MATLAB 运行入口
│   ├── analyze_E1.py           ← Python 汇总分析
│   └── results/                ← 运行时生成（CSV）
└── E2_scale_confound/          ← 实验二：尺度混淆检验
    ├── README_E2.md
    ├── run_E2.m
    ├── analyze_E2.py
    └── results/
```

## 运行顺序

```matlab
% MATLAB 命令行（与第二轮相同的用法：cd 进实验文件夹后直接调用函数）
cd 'D:\PlatEMO-master\PlatEMO-master\PlatEMO\Algorithms\Multi-objective optimization\REMO_new2_AdaMaO\notes\experiment_round3\E1_conf_validity'
run_E1        % 完整版约 10-30 分钟；快速试跑用 run_E1('n_run',2)

cd 'D:\PlatEMO-master\PlatEMO-master\PlatEMO\Algorithms\Multi-objective optimization\REMO_new2_AdaMaO\notes\experiment_round3\E2_scale_confound'
run_E2        % 完整版约 10-20 分钟；快速试跑用 run_E2('n_run',2)
```

跑完后（命令行 cmd/bash）：

```bash
cd "D:\PlatEMO-master\PlatEMO-master\PlatEMO\Algorithms\Multi-objective optimization\REMO_new2_AdaMaO\notes\experiment_round3"
py -3.13 -X utf8 E1_conf_validity\analyze_E1.py
py -3.13 -X utf8 E2_scale_confound\analyze_E2.py
```

E1 与 E2 使用相同的随机种子和快照生成器，**种群完全一致**，结果可互相印证。

## 与研究主线的关系

第一轮（发现现象）→ 第二轮（定位根因：判别力集中于 mean_conf）→
**第三轮 E1/E2（审判 mean_conf 本身）** → 分支：
E1 通过 → E4 阈值重设计；E1 失败 → 度量重设计（归一化 PBI + 校准）→ 再做 E3 型消融对比。
