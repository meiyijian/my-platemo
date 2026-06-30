# REMO_RandRed vs REMO_SpCorrRed 对比汇报文档

> 生成日期：2026-06-29
> 目的：测试两种目标降维方案在超多目标场景下的表现差异

---

## 目录

- [一、研究动机](#一研究动机)
- [二、两个算法概述](#二两个算法概述)
- [三、降维方法详细对比](#三降维方法详细对比)
- [四、PBI分类在降维前后的变化](#四pbi分类在降维前后的变化)
- [五、共同框架说明](#五共同框架说明)
- [六、参数说明](#六参数说明)
- [七、实验设计建议](#七实验设计建议)
- [八、预期现象与风险](#八预期现象与风险)
- [九、冒烟测试结果](#九冒烟测试结果)

---

## 一、研究动机

原始 REMO 在 M=2,3 时表现优秀，但在超多目标（M ≥ 10）场景下性能退化。核心原因之一：**关系模型需要在 2×M 维度的配对空间中学习，M 增大时输入维度高、样本相对稀疏，神经网络难以有效学习。**

降维方案的核心思路：通过目标聚类将 M 个目标压缩为 k_red 个聚合目标，代理模型只在 k_red 维空间中训练关系，降低学习难度。

本实验对比两种降维方式：
- **方案一（随机聚类）**：检验"随便降维"是否已经有效
- **方案二（Spearman聚类）**：检验"利用目标间结构信息降维"是否更好

如果 `SpCorrRed > RandRed > REMO`，说明"降维有效，且基于相关性的降维更好"；如果两者都不如 REMO，说明"仅改代理模型目标空间不足以解决问题"。

---

## 二、两个算法概述

| | REMO_RandRed | REMO_SpCorrRed |
|---|---|---|
| **全称** | REMO with Random Objective Reduction | REMO with Spearman Correlation Objective Reduction |
| **文件夹** | `REMO_RandRed/` | `REMO_SpCorrRed/` |
| **聚类方式** | `randperm` 随机排列 + 轮流分配 | Spearman 秩相关 + 层次聚类 |
| **分组固定性** | 初始化时确定，全程固定 | 初始化时确定，全程固定 |
| **组内聚合** | min-max 归一化 + 等权重平均 | min-max 归一化 + 等权重平均 |
| **与REMO差异** | 仅降维+PBI输入不同 | 仅降维+PBI输入不同 |
| **公共依赖** | `REMO/` 中的 6 个共享函数 | 同左 |

### 改动范围（相对原始REMO）

两个算法对原始 REMO 的改动**极小且一致**，仅有以下两处差异：

```
原始REMO                          新算法
───────────                      ────────────
① 参数：k, gmax                  → k_red, k, gmax
② PBI输入：PopObj, RefObj (M维)  → PopObj_red, RefObj_red (k_red维)
③ 其他：完全不变                   → 完全不变
```

---

## 三、降维方法详细对比

### 3.1 方案一：随机聚类 (`buildRandomGroups`)

```matlab
function Groups = buildRandomGroups(M, k_red)
    perm = randperm(M);          % 随机排列 1~M
    Groups = cell(1, k_red);
    for i = 1:M
        g = mod(i-1, k_red) + 1; % 轮流分配，保证每组大小均衡
        Groups{g}(end+1) = perm(i);
    end
end
```

**特点：**
- 完全不考虑目标间的任何关系
- 每组大小尽量均衡（差值 ≤ 1）
- 作为基线：回答"降维本身是否有效"的问题

### 3.2 方案二：Spearman 聚类 (`spearCluster`)

**Step 1 — 计算 Spearman 秩相关矩阵**

```matlab
rho = corr(PopObj, 'type', 'Spearman');   % M×M, ρ ∈ [-1, 1]
rho(isnan(rho)) = 0;
```

- 与 Pearson 不同，Spearman 对非线性单调关系也有效
- ρ = +1：完全正相关（两个目标同方向变化）
- ρ = -1：完全负相关（两个目标反方向变化）
- ρ = 0：无单调关系

**Step 2 — 构造距离矩阵**

```matlab
D = 1 - abs(rho);     % D(i,j) = 1 - |ρ(i,j)|
D(1:M+1:end) = 0;     % 对角线置 0
```

- |ρ| → 1（高度相关）→ 距离小 → 倾向聚在同一组
- |ρ| → 0（不相关）→ 距离大 → 倾向分到不同组
- 正相关和负相关同等对待（都表示有结构关系）

**Step 3 — 层次聚类**

```matlab
Z = linkage(squareform(D), 'average');
labels = cluster(Z, 'maxclust', k_red);
```

- `squareform`：将 M×M 矩阵转为 pdist 向量格式
- `linkage(..., 'average')`：组平均连接，平衡单连接和全连接的极端性
- `cluster(..., 'maxclust', k_red)`：切分为 k_red 组

**为什么用层次聚类而非 k-means？**
- k-means 需要数据在欧氏空间中，但 D 是目标间的距离矩阵，不是样本
- 层次聚类直接接受距离矩阵作为输入，更自然

### 3.3 组内聚合（两个方案共用）

```matlab
% Step 1: 逐列 min-max 归一化到 [0, 1]
F(:,d) = (col - min(col)) / (max(col) - min(col))

% Step 2: 组内等权重平均
ReducedObj(:,g) = mean(F(:, Groups{g}), 2)
```

**为什么用等权重？**
- 控制变量：两个方案只在分组方式上有差异，聚合方式一致
- 简单可解释：每组一个聚合值 = 组内归一化目标的算术平均
- 如果方案二用加权（如基于结构可靠性），就混入了额外的设计变量

---

## 四、PBI 分类在降维前后的变化

### 4.1 降维前（原始REMO，M维）

```
输入：PopObj (N×M), RefObj (k×M)
空间分配：ref_index(i) = argmax(cos(PopObj(i,:), RefObj(j,:)))  在M维空间
PBI计算：d1 = normP × cos(θ), d2 = normP × sin(θ)              在M维空间
分类：g = (d1 + δ×d2) / normR, g>1 → "不好"
```

**含义**：判断解在 M 维 Pareto 前沿上是否靠近某个参考解。考虑了全部 M 个目标的独立值。

### 4.2 降维后（新算法，k_red维）

```
输入：PopObj_red (N×k_red), RefObj_red (k×k_red)
空间分配：ref_index(i) = argmax(cos(PopObj_red(i,:), RefObj_red(j,:)))  在k_red维空间
PBI计算：d1 = normP × cos(θ), d2 = normP × sin(θ)                       在k_red维空间
分类：g = (d1 + δ×d2) / normR, g>1 → "不好"
```

**含义**：判断解在 k_red 维聚合空间中的优劣。不再直接感知 M 维目标的独立值。

### 4.3 本质变化

| | 降维前（M维） | 降维后（k_red维） |
|---|---|---|
| 空间维度 | M（如10维） | k_red（如3维） |
| 判断依据 | 解在M维Pareto前沿上的位置 | 解在k_red维聚合空间中的位置 |
| 保留信息 | 全部M个目标的独立值 | M个目标被压缩为k_red个聚合值 |
| 丢失信息 | 无 | 组内目标间的 trade-off 关系 |
| 计算复杂度 | O(N×k×M) | O(N×k×k_red) |
| 代码 | `GetOutput_PBI(PopObj, RefObj)` | `GetOutput_PBI(PopObj_red, RefObj_red)` ← 完全相同的函数 |

**关键风险**：如果组内目标冲突严重（如 f1 和 f2 负相关），聚合值会抹平 trade-off 信息。例如：

```
解 X: f1=0.1, f2=0.9 → Fg = (0.1+0.9)/2 = 0.5
解 Y: f1=0.5, f2=0.5 → Fg = (0.5+0.5)/2 = 0.5
```
PBI 在降维空间中看到两个解完全相同，但它们在原始 M 维空间中完全不同。

**这正是方案二要解决的问题**：通过 Spearman 聚类，将高度相关的目标聚在一组，减少组内冲突；将不相关/负相关的目标分到不同组，保留组间 trade-off。

---

## 五、共同框架说明

两个算法与原始 REMO 的框架完全一致，仅替换了 PBI 分类的输入。

```
初始化
  │
  ├── Latin Hypercube 采样 (同REMO)
  ├── 真实评估 (同REMO)
  ├── ★ 构建降维分组 Groups (仅一次)
  │
  ▼
┌── 主循环 ─────────────────────────────────────────────┐
│                                                       │
│  RefSelect(Population, k)          ← 在原M维空间      │
│       │                                               │
│  ★ PopObj_red = applyReduction(PopObj, Groups)        │
│  ★ RefObj_red = applyReduction(Ref.objs, Groups)      │
│  Catalog = GetOutput_PBI(PopObj_red, RefObj_red)       │
│       │                                               │
│  GetRelationPairs(Input, Catalog)   ← 同REMO           │
│       │                                               │
│  DataProcess → patternnet → train  ← 同REMO           │
│       │                                               │
│  RSurrogateAssistedSelection       ← 同REMO           │
│       │                                               │
│  真实评估                           ← 同REMO           │
│       │                                               │
│  RefSelect(Archive, N)              ← 在原M维空间      │
│                                                       │
└───────────────────────────────────────────────────────┘
```

**依赖的 REMO 共享函数（通过 addpath 引用，不复制）：**

| 函数 | 文件 | 作用 |
|------|------|------|
| `RefSelect` | `REMO/RefSelect.m` | 参考解选择 |
| `GetOutput_PBI` | `REMO/GetOutput_PBI.m` | PBI 分类 |
| `GetRelationPairs` | `REMO/GetRelationPairs.m` | 关系对构建 |
| `DataProcess` | `REMO/DataProcess.m` | 训练/测试集划分 |
| `onehotconv` | `REMO/onehotconv.m` | 独热编码转换 |
| `RSurrogateAssistedSelection` | `REMO/RSurrogateAssistedSelection.m` | 代理模型辅助选择 |

---

## 六、参数说明

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `k_red` | 3 | 降维后的目标组数。**仅当 M > k_red 时有效，否则报错** |
| `k` | 6 | 参考解数量（与 REMO 一致） |
| `gmax` | 3000 | 代理模型评估解数量上限（与 REMO 一致） |

---

## 七、实验设计建议

### 第一轮：降维方案对比（核心实验）

```
算法：  REMO (baseline),
        REMO_RandRed (k_red=3),
        REMO_SpCorrRed (k_red=3)

问题：  DTLZ2, DTLZ3
M：     10, 15
D：     10
maxFE： 300
独立运行：10 次

指标：  IGD（主指标）
        代理模型分类错误率 p_err（辅助诊断）
        降维分组信息（仅 SpCorrRed，用于分析聚类质量）
```

### 第二轮（可选）：k_red 消融

```
算法：   REMO_SpCorrRed (k_red=2),
         REMO_SpCorrRed (k_red=3),
         REMO_SpCorrRed (k_red=5)
问题：   DTLZ2, M=15
```

### 第三轮（可选）：更多测试问题

```
追加：   WFG4, WFG9
M：      10, 15
目的：   验证结论的泛化性
```

---

## 八、预期现象与风险

### 8.1 预期现象

| 场景 | 预期 | 解释 |
|------|------|------|
| `SpCorrRed > RandRed > REMO` | **最理想** | 降维有效，且基于结构信息的降维更好 |
| `RandRed > REMO` 但 `SpCorrRed ≈ RandRed` | 部分理想 | 降维有效但聚类方式不重要 |
| `SpCorrRed > REMO` 但 `RandRed ≤ REMO` | 有趣 | 只有基于结构的降维才有用 |
| 两者都 < REMO | 重要负结果 | 仅改代理空间不足以解决超多目标问题 |

### 8.2 主要风险

1. **Spearman估计不稳健**
   - 初始样本仅 N≈100，M=15 时相关矩阵可能不稳定
   - 如果分组质量差，SpCorrRed 可能不如 RandRed
   - 缓解：可在诊断日志中输出聚类结果供人工检查

2. **组内冲突目标聚合损失**
   - 即使 Spearman 聚类，组内仍可能有非完美相关的目标
   - k_red 越小，信息损失越大
   - 缓解：k_red=3 作为主要测试值，避免 k_red=2 的极端情况

3. **参考解在降维空间中代表性下降**
   - Ref 在原 M 维空间选出代表 Pareto 前沿不同区域
   - 降维后这些 Ref 可能在 k_red 空间挤在一起
   - 缓解：这是方案固有限制，可在论文中讨论

4. **随机种子的影响**
   - REMO_RandRed 的随机分组结果依赖 `randperm` 的种子
   - 单次运行的 IGD 可能波动较大（分组好 vs 分组差）
   - 缓解：多次独立运行取均值，建议至少10次

---

## 九、冒烟测试结果

| 测试项 | 问题 | M | D | maxFE | 结果 | 说明 |
|--------|------|---|---|-------|------|------|
| REMO_RandRed 初始化 | DTLZ2 | 10 | 10 | 50 | ✅ PASS | 正常启动，无错误 |
| REMO_RandRed 主循环 | DTLZ2 | 10 | 10 | 150 | ✅ PASS | 多代迭代正常 |
| REMO_SpCorrRed 初始化 | DTLZ2 | 10 | 10 | 50 | ✅ PASS | Spearman聚类正常 |
| M=k_red 报错 | — | — | — | — | ✅ PASS | 参数检查生效 |

运行命令：
```matlab
platemo('algorithm', @REMO_RandRed, 'problem', @DTLZ2, 'M', 10, 'D', 10, 'maxFE', 150, 'N', 100);
platemo('algorithm', @REMO_SpCorrRed, 'problem', @DTLZ2, 'M', 10, 'D', 10, 'maxFE', 150, 'N', 100);
```

---

## 附录：代码文件清单

```
REMO_RandRed/
├── REMO_RandRed.m                ← 主算法（方案一：随机聚类降维）
└── smoke_test_RandRed.m          ← 冒烟测试脚本

REMO_SpCorrRed/
├── REMO_SpCorrRed.m              ← 主算法（方案二：Spearman聚类降维）
├── smoke_test_SpCorrRed.m        ← 冒烟测试脚本
└── REMO_RandRed_vs_SpCorrRed_对比汇报.md  ← 本文档
```
