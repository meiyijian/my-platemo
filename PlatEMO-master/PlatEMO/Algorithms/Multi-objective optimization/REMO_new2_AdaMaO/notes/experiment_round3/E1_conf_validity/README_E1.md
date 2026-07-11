# E1：confidence 效度检验（conf 是否真的预测"分类正确性"）

> 创建：2026-07-11 ｜ 状态：**待运行**
> 上游：第二轮实验发现 relation_mode 判别力全在 `mean_conf>=0.55` 一个条件上
> 本实验回答：**confidence 这个量本身有没有信息？**

## 一、实验目的

`HybridPBI_Classification` 输出的 `confidence = 1 - |score_v - label_dyn|`
被算法当作"分类可靠性"使用：

- 门控：`mean_conf >= 0.55` 决定是否进入 weighted 关系对模式；
- 加权：weighted 模式下 `Ws = sqrt(conf_i * conf_j)` 作为关系对训练权重。

这两个用法的合法性都建立在同一个**从未验证过的假设**上：
**conf 高的解，其好/坏分类更可能正确**。本实验直接检验该假设。

## 二、实验设计

### 2.1 数据生成（静态，不跑 REMO 全流程）

- 问题：DTLZ1/2/4/7 + WFG3/4/6/9（与前两轮一致），M=[10,20]，D=30，N=100；
- 用**代理进化**（GA 算子 + RefSelect 截断，真实评估）生成 5 个阶段的种群快照
  （gen = 0/2/5/10/20，对应 ratio = 0.33/0.5/0.67/0.83/1.0），覆盖"随机→收敛"谱系；
- 每问题×M 独立 5 次（seed=1..5，与 E2 完全相同的快照）；
- 对每个快照调用**原版** `HybridPBI_Classification`（零改动，k_eff 与 Stat 版一致）。

### 2.2 真值构造（两种口径做稳健性）

用真实目标值构造"真值好类"（前 N/4=25 个），见 `../common/truth_labels.m`：

- **口径 A（纯收敛）**：非支配层级 → 归一化目标范数；
- **口径 B（收敛+分布）**：非支配层级 → 归一化空间 PBI（theta=5，均匀参考向量），
  更贴近 HPC"收敛+方向分布"的混合目标概念。

结论若在两口径下一致，则不依赖真值定义细节。

### 2.3 指标

| 层面 | 指标 | 含义 |
|---|---|---|
| 解级 | AUC(conf → 分类正确) | conf 高的解是否更可能分对 |
| 关系对级 | AUC(Ws → 关系标签正确) | 下游真实用法：加权是否加对了地方 |
| 参考 | acc（分类正确率）、mean_conf | 背景量 |

关系对按 `GetRelationPairs_confidence` 的四块构造复刻（C1C1/C2C2/C1C2/C2C1）。

### 2.4 判据（预注册）

- **AUC > 0.6**：conf 有信息 → 问题在阈值放置 → 走 E4（阈值重设计）；
- **0.55 < AUC < 0.6**：弱有效 → 度量改良与阈值重设计并行；
- **AUC ≈ 0.5**：conf 无效 → 直接重设计度量，跳过对旧度量的 E3 消融。

分析 E 段还检查**语义混淆的方向性**：按预测类（好/坏）分层算组内 AUC——
若总体 AUC 主要来自"标坏的解 conf 机械偏高"，分层后 AUC 会塌回 0.5。

## 三、如何运行

```matlab
% MATLAB（约 10–30 分钟，无模型训练）
cd 'D:\PlatEMO-master\PlatEMO-master\PlatEMO\Algorithms\Multi-objective optimization\REMO_new2_AdaMaO\notes\experiment_round3\E1_conf_validity'
run_E1               % 完整版
run_E1('n_run',2)    % 快速试跑
```

```bash
# 然后（命令行）
cd "D:\PlatEMO-master\PlatEMO-master\PlatEMO\Algorithms\Multi-objective optimization\REMO_new2_AdaMaO\notes\experiment_round3\E1_conf_validity"
py -3.13 -X utf8 analyze_E1.py
```

## 四、输出文件

| 文件 | 内容 |
|---|---|
| `results/E1_summary.csv` | 每快照一行（400 行）：AUC/ACC/mean_conf 等 16 列 |
| `results/E1_solution_level.csv` | 逐解明细（40000 行）：conf、分类、两口径真值与正确性 |

## 五、已知局限（诚实记录，写报告时要提）

1. 快照来自代理进化而非 REMO 真实轨迹（round2 未保存种群）。E1 检验的是
   度量的数学性质，对种群来源不敏感，但严格说结论适用于"REMO 同型种群"；
2. 真值好类以收敛为主导（口径 B 已含分布性）；HPC 的"好"概念无唯一真值，
   故用双口径稳健性设计；
3. 静态检验不涉及关系模型训练，回答的是"权重加得对不对"，
   不直接回答"加权后模型变好多少"（那是 E3 消融的问题）。
