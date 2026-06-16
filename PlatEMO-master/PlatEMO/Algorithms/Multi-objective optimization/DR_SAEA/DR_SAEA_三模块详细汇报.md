# DR_SAEA 算法核心模块详细汇报

> **全称**：Dimension Reduction based Surrogate-Assisted Evolutionary Algorithm（基于降维的代理辅助进化算法）
> **平台**：PlatEMO（MATLAB）
> **定位**：面向昂贵超多目标优化（expensive many-objective optimization, M ≥ 5）的模块化 SAEA
> **代码位置**：`PlatEMO/Algorithms/Multi-objective optimization/DR_SAEA/`

---

## 一、算法总体概述

### 1.1 核心思想

DR_SAEA 的设计哲学可以用一句话概括：

> **在原始 M 维目标空间进行真实评估，但用降维后的 K 维目标训练代理模型、构造采集函数，从中挑选优质解送下一轮真实评估。**

它由三个**解耦可插拔**的核心模块组成：

| 模块                   | 源文件                                 | 职责                                                                        |
| ---------------------- | -------------------------------------- | --------------------------------------------------------------------------- |
| **降维模块**     | `reduceObjectives.m`                 | 将原始 M 维目标映射到 K 维（K < M），作为代理建模与采集函数的中间表示       |
| **代理模型模块** | `buildSurrogate.m`                   | 在降维后的 K 维目标上训练代理模型（Kriging/RBF/Relation），并对候选解做预测 |
| **填充采样模块** | `infillSelect.m` + `computeEHVI.m` | 基于代理预测，在降维空间中通过采集函数挑选 BatchSize 个最有价值的候选点     |

### 1.2 关键设计原则

1. **降维仅是中间过程**：所有最终输出（Pareto 解集、HV/IGD 指标）均基于 M 维原始目标，绝不修改 PROBLEM 基类。
2. **三大模块解耦可插拔**：每个模块暴露枚举式配置接口，新增策略只需追加一个 `case` 分支，无需改动主循环。
3. **零硬依赖**：相关性聚类自实现平均连接层次聚类；RBF 内部重建，避免对 Statistics Toolbox 或 ADSAPSO 目录的运行时依赖。
4. **复用 PlatEMO 工具链**：LHS 采样、GA 算子、非支配排序、归一化、DACE/Kriging 训练全部复用 PlatEMO 自带工具。

### 1.3 主流程与三大模块的协同

```
┌────────────────────────────────────────────────────────────────────┐
│  初始化阶段                                                         │
│   ① LHS 初始采样 NI = max(2D, InitialSampleRate × D)，真实评估      │
│   ② 【降维模块】  reduceObjectives → GroupMap, Fmin, Fmax            │
│   ③ 【降维模块】  applyReduction  → K 维降维目标 Zall                │
│   ④ 【代理模块】  buildSurrogate(Archive.decs, Zall) → Models        │
└────────────────────────────────────────────────────────────────────┘
                                ↓
┌────────────────────────────────────────────────────────────────────┐
│  迭代循环（直到 Problem.FE ≥ Problem.maxFE）                          │
│   a) GA 算子生成候选解池（PoolSize ≈ max(50D, 100)）                  │
│   b) 【代理模块】  buildSurrogate(Models, CandDec) → Mu, Sigma        │
│   c) 【采样模块】  infillSelect(CandDec, Mu, Sigma, ...) → NewDec     │
│   d) 真实评估 NewDec，追加到 Archive                                  │
│   e) 【降维模块】  仅对新样本应用 GroupMap 计算降维目标，拼接 Zall      │
│   f) 【代理模块】  全量重训练 Models                                  │
└────────────────────────────────────────────────────────────────────┘
```

三个模块通过 **Archive（解集容器）** 与 **降维目标矩阵 Zall** 两类数据耦合：

- Archive 保留 M 维原始目标（真实评估用）；
- Archive(i).add 保留 K 维降维目标（代理与采集用）。

---

## 二、降维模块（Dimension Reduction）—— `reduceObjectives.m`

### 2.1 模块定位

降维模块是 DR_SAEA 的**第一性创新点**：它把超多目标优化（M ≥ 5）中代理模型面临的"维度灾难"转化为低维（K=2）的代理建模问题，让 Kriging/RBF 的训练开销和 EHVI 采集函数的计算都成为可行。

**输入 / 输出契约**：

```matlab
% 计划模式（Planning）：首次调用，建立分组方案与归一化基线
[GroupMap, Fmin, Fmax] = reduceObjectives(PopObj, K, Strategy, Seed)

% 应用模式（Apply）：后续调用，复用既定方案对任意新样本降维
Z = reduceObjectives(PopObj, K, Strategy, Seed, GroupMap, Fmin, Fmax)
```

| 参数          | 含义                                              |
| ------------- | ------------------------------------------------- |
| `PopObj`    | N×M 原始目标矩阵                                 |
| `K`         | 降维后目标数（必须 < M）                          |
| `Strategy`  | `'random'` 或 `'correlation'`                 |
| `Seed`      | `'random'` 策略的随机种子                       |
| `GroupMap`  | 1×M 整数向量，记录每个原始目标归属的组号（1..K） |
| `Fmin/Fmax` | 1×M 归一化基线（仅基于初始样本计算，全程不变）   |
| `Z`         | N×K 降维目标矩阵                                 |

### 2.2 两种降维策略

#### 2.2.1 随机分组策略（`'random'`）—— 默认

```matlab
rng(Seed, 'twister');          % 固定种子 → 结果可复现
order = randperm(M);           % 对 M 个目标做一次随机置换
% 均衡轮询分配：保证各组大小差 ≤ 1
for g = 1 : K
    GroupMap((g:K:M)) = g;
end
```

**特点**：

- **完全可复现**：固定 `Seed` 后分组方案确定，便于实验对照。
- **零数据依赖**：不依赖样本质量，即便 N 极小也能稳定分组。
- **适用场景**：小样本（N < M+2）、目标间无明显相关性结构、或作为基准对照组。

#### 2.2.2 相关性聚类分组策略（`'correlation'`）—— 数据驱动

核心思想：**相关性强的目标应聚到同一组**（合并后信息损失最小）。

**Step 1：计算 Pearson 相关距离**

```matlab
R = corrcoef(PopObj);      % M×M 相关系数矩阵
D = 1 - abs(R);            % 距离 = 1 - |r|，强相关 → 距离小
```

**Step 2：自实现平均连接层次聚类（average-linkage agglomerative clustering）**

DR_SAEA **不依赖 Statistics Toolbox 的 `linkage`/`cluster`**，而是手写了完整的凝聚式聚类算法，关键更新公式（`reduceObjectives.m:191`）：

```
d(i∪j, k) = (|i|·d(i,k) + |j|·d(j,k)) / (|i| + |j|)     ← 平均连接 (UPGMA)
```

算法流程：

1. 初始每目标自成一簇；
2. 反复合并距离最近的两个簇，直至剩下 K 簇；
3. 合并后用 UPGMA 公式更新簇间距离。

**自动降级保护**：当 N < 3 或 M ≤ K 时，Pearson 相关不可靠，自动退化为均衡轮询分组：

```matlab
if N < 3 || M <= K
    % Fallback to a balanced round-robin grouping
    ...
end
```

### 2.3 组内聚合机制（`applyReduction`）

降维目标的生成分两步：

**第一步：min-max 归一化**（基于既定基线 Fmin/Fmax）

```matlab
Norm = (PopObj - Fmin) ./ (Fmax - Fmin);
Norm = max(min(Norm, 1), 0);        % 裁剪到 [0,1]
```

**第二步：组内等权求均值**

```matlab
for g = 1 : K
    members = (GroupMap == g);
    Z(:, g) = mean(Norm(:, members), 2);   % 组内等权平均
end
```

**设计要点**：

- 用 `mean` 而非 `sum` 聚合：使 K=1 退化和 K>1 时输出范围一致（均在 [0,1]），便于代理训练和采集函数归一化。
- **基线锁定**：Fmin/Fmax 仅在初始化时计算一次，全程不变。这保证新旧样本的降维目标可比，但代价是：后期若出现远超初始范围的目标，归一化值会被裁剪到边界，损失区分度。

### 2.4 降维模块的工程亮点

| 亮点                 | 说明                                                          |
| -------------------- | ------------------------------------------------------------- |
| **双调用模式** | 计划/应用两态分离，分组方案一旦确定即全程复用，保证降维一致性 |
| **零外部依赖** | 层次聚类、相关性距离全部自实现，不要求 Statistics Toolbox     |
| **健壮性保护** | 常量目标除零保护、小样本自动降级、K 越界自动 clamp            |
| **可复现性**   | `'random'` 策略固定种子，分组方案跨运行一致                 |

### 2.5 已知限制

- **基线不更新**：Fmin/Fmax 全程锁定，后期 Archive 目标超出初始范围时归一化裁剪损失区分度。建议每 N 轮用全 Archive 重算基线（需同步重训代理）。
- **小样本降级**：N < 3 时相关性策略自动退化为随机，此时无数据驱动优势。
- **线性聚合局限**：组内等权平均是线性聚合，无法表达目标间的非线性权衡关系。

---

## 三、代理模型模块（Surrogate Model）—— `buildSurrogate.m`

### 3.1 模块定位

代理模型模块在**降维后的 K 维目标**上训练代理，对候选解做均值/不确定度预测，是采集函数决策的核心依据。它通过**函数重载**（根据首参类型自动区分训练/预测模式）实现统一入口。

**输入 / 输出契约**：

```matlab
% 训练模式：首参为决策矩阵 Dec
[Models, TrainDec] = buildSurrogate(Dec, Z, SurrogateType, D, K)

% 预测模式：首参为已训练的 cell 数组 Models
[Mu, Sigma] = buildSurrogate(Models, X, SurrogateType, TrainDec)
```

| 参数              | 含义                                                   |
| ----------------- | ------------------------------------------------------ |
| `Dec / X`       | N×D 训练决策 / Nq×D 候选决策                         |
| `Z`             | N×K 降维目标（注意：训练的是降维目标，非原始 M 维！） |
| `SurrogateType` | `'Kriging'` / `'RBF'` / `'Relation'`             |
| `Models`        | 1×K cell 数组，每个元素是一个独立的代理模型           |
| `Mu`            | Nq×K 预测均值                                         |
| `Sigma`         | Nq×K 预测标准差（不确定度）                           |

### 3.2 三种代理类型

#### 3.2.1 Kriging（高斯过程）—— 默认，精度最高

**训练**（每个降维目标独立训练一个 GP）：

```matlab
theta0 = 0.5 * ones(1, D);     % 相关长度初值
lob    = 1e-5 * ones(1, D);    % 下界
hib    = 20   * ones(1, D);    % 上界
dmodel = dacefit(Dec, Z(:,k), 'regpoly1', 'corrgauss', theta0, lob, hib);
```

- `regpoly1`：一阶多项式趋势项；
- `corrgauss`：高斯相关函数；
- 参数沿用 **K-RVEA 的经验设定**，对 D ≤ 15 数值稳定。

**预测**（含 MSE 不确定度，DACE 标准接口）：

```matlab
% 多点路径：第 2 输出即 MSE
[y, mse] = predictor(X, dmodel);
% 单点路径：第 3 输出才是 MSE（DACE 接口约定）
[y, ~, mse] = predictor(X, dmodel);
Sigma = sqrt(max(mse, 0));
```

**关键工程细节**：`buildSurrogate.m:123` 区分了 DACE 单点/多点预测的输出约定（`mx` 不同时 MSE 的输出位置不同），避免误取梯度值当 MSE。

#### 3.2.2 RBF（径向基函数）—— 自包含实现

为避免对 `ADSAPSO/RBF/` 目录的运行时依赖，DR_SAEA **自实现**了高斯核 RBF：

**训练**（`rbfCreateLocal`）：

```matlab
% 决策变量 min-max 归一化到 [-1,1]
axn = 2 ./ (xmax - xmin) .* (ax - xmin) - 1;
% 高斯核矩阵
r   = dist(axn, axn');
Phi = radbas(sqrt(-log(0.5)) * r);
% 加上多项式趋势项的增广线性方程组
P   = [ones(N,1), axn];
A   = [Phi, P; P', zeros(D+1,D+1)];
theta = A \ b;            % 求解 RBF 系数 α + 多项式系数 β
```

**预测**（`rbfInterpLocal`）：

```matlab
y = Phi_x * para.alpha + [ones(nx,1), xn] * para.beta;
% 反归一化回原目标尺度
```

**RBF 的不确定度代理**（关键设计取舍，`buildSurrogate.m:153`）：

```matlab
% RBF 没有原生不确定度，用"到最近训练点的欧氏距离"近似
D2 = pdist2(X, TrainDec);
minD = min(D2, [], 2);
Sigma(:, k) = minD;
```

- **优点**：远离训练集的点不确定度高，符合"探索"直觉；
- **局限**：所有 K 个降维目标的 Sigma 完全相同，无法体现各目标方向的差异（RBF 的固有局限）。

#### 3.2.3 Relation（关系学习）—— 占位

```matlab
otherwise   % 'relation'
    Models{k} = [];
```

当前实现是占位：返回空模型，预测时 Mu/Sigma 全为 0，主循环会自动回退到基于 NDSort 的 Pareto 前沿选择。如需启用完整 SVM 排序，建议接入 `fitcsvm`。

### 3.3 三种代理的对比

| 类型               | 训练复杂度        | 不确定度来源           | 适用场景               | 依赖         |
| ------------------ | ----------------- | ---------------------- | ---------------------- | ------------ |
| **Kriging**  | O(N³) per target | DACE 原生 MSE          | 精度优先、N ≤ 200     | DACE Toolbox |
| **RBF**      | O(N³) 矩阵求解   | 最近邻欧氏距离（近似） | 速度优先、无 DACE 环境 | 无外部依赖   |
| **Relation** | —                | —                     | 占位/扩展              | —           |

### 3.4 重载设计的工程取舍

`buildSurrogate` 通过"首参类型自动分派"实现训练/预测两种模式：

```matlab
if iscell(Dec) && ~isempty(Dec) && isstruct(Dec{1})
    % 预测模式：Dec 实为 Models，Z 实为 X，D 实为 TrainDec
    ...
else
    % 训练模式
    ...
end
```

源码注释明确提示了这种"重载"的风险（`buildSurrogate.m:43`）：

> 容易引入参数语义混淆（Z → X, D → TrainDec）。修改代码时务必确认调用方传参顺序。

### 3.5 代理模块的已知限制

- **全量重训练**：每轮迭代重新训练全部 K 个代理（O(K·N³)），Archive 增长到 200+ 时开销显著，可考虑增量更新（如 Kriging 的 Online 更新）。
- **DACE 奇异矩阵敏感**：当训练决策变量含强重复行时，Kriging 训练可能报 NaN（主类已用 `CalDec` 修复越界，但不去重）。
- **RBF 归一化除零**：收敛后期某决策维取值相同时，`xmax==xmin` 导致除零 → Inf（LHS 初始采样下罕见）。
- **`warning('off')` 全局静默**：RBF 训练时关闭所有警告，会压制矩阵奇异等诊断信号，建议改为针对性关闭。

---

## 四、填充采样模块（Infill Sampling）—— `infillSelect.m` + `computeEHVI.m`

### 4.1 模块定位

填充采样模块是 DR_SAEA 决策"下一批评估哪些点"的核心。它基于代理预测的 (Mu, Sigma)，在降维空间中按采集函数挑出 BatchSize 个最有价值的候选解，并施加去重和多样性约束。所有决策都在 K 维降维空间进行。

**输入 / 输出契约**：

```matlab
[Selected, Info] = infillSelect(CandDec, Mu, Sigma, Zref, ArchDec, ...
                                K, Strategy, BatchSize, Phase, D)
```

| 参数           | 含义                                                         |
| -------------- | ------------------------------------------------------------ |
| `CandDec`    | Nq×D 候选决策矩阵                                           |
| `Mu / Sigma` | Nq×K 代理预测均值/标准差                                    |
| `Zref`       | 当前非支配前沿的 K 维降维目标（用于 HV 参考）                |
| `ArchDec`    | 当前 Archive 决策变量（用于去重）                            |
| `Strategy`   | `'balanced'` / `'exploitation'` / `'exploration'`      |
| `BatchSize`  | 每轮选取的填充点数                                           |
| `Phase`      | `Problem.FE / Problem.maxFE ∈ [0,1]`，自适应切换探索/开发 |
| `Selected`   | BatchSize×D 最终选中的决策变量                              |
| `Info`       | 诊断结构体（选中索引、各分项得分）                           |

### 4.2 采集函数的四步处理流程

```
候选解池 CandDec (Nq×D)
        │
        ▼
┌───────────────────────────────┐
│ Step 1: 去重                    │  剔除与 Archive 过近的点 (阈值 1e-6×对角线)
└───────────────────────────────┘
        │
        ▼
┌───────────────────────────────┐
│ Step 2: 计算各候选的采集分项      │
│   - Mu/Sigma 归一化到 [0,1]      │
│   - convScore (收敛)             │
│   - uncScore  (不确定度)         │
│   - ehviN     (K=2 时 EHVI)      │
└───────────────────────────────┘
        │
        ▼
┌───────────────────────────────┐
│ Step 3: 按策略合成标量采集分      │
│   - exploitation / exploration / balanced
└───────────────────────────────┘
        │
        ▼
┌───────────────────────────────┐
│ Step 4: 贪心批选 + 多样性惩罚    │  逐点选最优，邻域 (0.05×对角线) ±1.0 惩罚
└───────────────────────────────┘
        │
        ▼
   Selected (BatchSize×D)
```

### 4.3 三种采集策略

#### 4.3.1 三项核心指标的归一化

所有指标先归一化到 [0,1]（基于当前候选池的 min/max），保证各策略间的标量分数可比：

| 指标          | 公式                                                                                    | 方向                |
| ------------- | --------------------------------------------------------------------------------------- | ------------------- |
| `convScore` | `sum(MuN, 2)`（K 维归一化均值之和）                                                   | 越小越好（收敛）    |
| `uncScore`  | `mean(SigmaN, 2)`（K 维归一化不确定度均值）                                           | 越大越好（探索）    |
| `ehviN`     | `computeEHVI(...) / max(ehvi)`，K=2 闭式；K>2 退化为 `1 - convScore/max(convScore)` | 越大越好（HV 改善） |

#### 4.3.2 三种策略的合成公式

```matlab
switch lower(Strategy)
    case 'exploitation'          % 纯开发：直接最小化收敛分
        score = convScore;
        lowerBetter = true;
    case 'exploration'           % 纯探索：直接最大化不确定度
        score = uncScore;
        lowerBetter = false;
    otherwise   % 'balanced'     % 自适应平衡：前期偏探索，后期偏开发
        if Phase < 0.3
            wU = 0.7; wC = 0.3;   % 前期：70% 探索
        else
            wU = 0.3; wC = 0.7;   % 后期：70% 开发（EHVI）
        end
        score = wC * ehviN + wU * uncScore;   % 两项均"越大越好"
        lowerBetter = false;
end
```

**`balanced` 策略的设计精妙处**：`ehviN`（HV 改善）和 `uncScore`（不确定度）都是"越大越好"的指标，直接加权不会出现 punishment vs reward 的符号歧义。

### 4.4 2D 闭式 EHVI（`computeEHVI.m`）

当 K = 2 时，DR_SAEA 用**精确闭式**计算每个候选对当前 Pareto 前沿的超体积改善量（Hypervolume Improvement），避免高维 EHVI 的蒙特卡洛积分开销。

#### 4.4.1 命名澄清（重要）

源码注释明确说明（`computeEHVI.m:27`）：

> 函数名为 `computeEHVI` 系沿用文献习惯，但当前实现是**确定性 HV 改善量（HVI）**，而非对高斯后验做积分的 Expected HVI。

当代理类型为 Kriging 且仅用预测均值 Mu 作为点估计时，计算结果与 Hupkens 2013 的 2D 闭式 EHVI 在均值点估计下数值一致。若需要真正的 EHVI（高斯积分），需额外传入 Sigma 并做数值积分。

#### 4.4.2 算法原理

点 p 的 HV 贡献 = `HV(F ∪ {p}) - HV(F)`，等价于矩形 `[p, RefPoint]` 中尚未被前沿 F 支配的面积。

**扫描法实现**（O(Nf) per candidate）：

1. **完整矩形面积**：`base = (ref1 - p1) × (ref2 - p2)`；
2. **计算被 F 覆盖的面积**：沿 f1 轴从 p1 向 ref1 扫描，遇到降低 f2 天花板的点就累加该段被覆盖面积；
3. **贡献量**：`max(base - covered, 0)`。

```matlab
% 核心扫描循环（computeEHVI.m:103）
for j = 1 : size(Fscan, 1)
    f = Fscan(j, :);
    if f(2) >= curCeil
        continue;          % 未降低天花板，跳过
    end
    segW = f(1) - prevF1;
    effCeil = max(curCeil, p(2));
    covered = covered + segW * (RefPoint(2) - effCeil);
    curCeil = f(2);
    prevF1  = f(1);
end
```

### 4.5 强制约束与鲁棒性

#### 4.5.1 去重约束

```matlab
diagLen = norm(max(ArchDec) - min(ArchDec)) + eps;
dupTol  = 1e-6 * diagLen;                    % 阈值相对决策空间对角线归一化
keepMask = minD > dupTol;                    % 剔除过近候选
```

- **保护机制**：若全部候选被判为重复，放宽阈值保留最远的 BatchSize 个，避免空选。

#### 4.5.2 批内多样性惩罚

```matlab
minDistThr = 0.05 * diagLen;                 % 邻域阈值
% 贪心每选一个点后，对其邻域候选施加 ±1.0 惩罚
if lowerBetter
    score(close) = score(close) + 1.0;       % 推低（越小越好方向）
else
    score(close) = score(close) - 1.0;       % 推低（越大越好方向）
end
```

#### 4.5.3 主循环回退机制（`DR_SAEA.m:106`）

```matlab
if isempty(NewDec)
    % 采集函数选不到点时，用 farthest-point 采样保证主循环不挂死
    NewDec = farthestPoint(Archive.decs, min(BatchSize, size(Archive.decs,1)));
end
```

### 4.6 填充采样模块的已知限制

- **多样性惩罚量级固定**：固定 ±1.0，但 `exploitation` 的 score ∈ [0,K]、`exploration/balanced` 的 score ∈ [0,1]，对后者惩罚过大，第二轮几乎无法再选点。建议惩罚量随各策略 score 范围自适应。
- **EHVI 是点估计**：未对高斯后验积分，与文献"Expected HVI"在 Kriging 下需补充 Sigma 积分。
- **去重阈值偏严**：1e-6 仅过滤几乎完全相同的点，对昂贵优化可放宽到 1e-3 以更有效避免近重复评估。

---

## 五、三大模块的协同与数据流

### 5.1 数据契约矩阵

| 模块           | 输入                      | 输出                             | 与谁耦合                                 |
| -------------- | ------------------------- | -------------------------------- | ---------------------------------------- |
| **降维** | Archive.objs (M 维)       | GroupMap, Fmin/Fmax, Zall (K 维) | 写入 Archive.add，供代理与采样读取       |
| **代理** | Archive.decs + Zall       | Models, Mu/Sigma                 | 训练读降维目标，预测供采样               |
| **采样** | CandDec + Mu/Sigma + Zref | NewDec                           | 决策全在降维空间，输出决策变量送真实评估 |

### 5.2 一次迭代的数据流转

```
Archive(M维真实目标) ──降维模块──▶ Zall(K维)
        │                              │
        │                              ▼
        │                       代理模块(训练)
        │                              │ Models
        ▼                              ▼
   GA候选池 ──────────────▶ 代理模块(预测) ──▶ Mu, Sigma
                                                    │
                                              采样模块 ◀── Zref(降维前沿)
                                                    │
                                                    ▼
                                             NewDec(BatchSize个)
                                                    │
                                              真实评估(M维)
                                                    │
                                                    ▼
                                          Archive 更新 + Zall 追加
```

### 5.3 模块可插拔性验证

每个模块都通过枚举式配置接入主循环，**新增策略无需改主类**：

| 扩展类型   | 改动范围                                         | 示例                   |
| ---------- | ------------------------------------------------ | ---------------------- |
| 新降维策略 | `reduceObjectives.m` 加一个 `case`           | `'LDA'` 线性判别分组 |
| 新代理类型 | `buildSurrogate.m` 训练/预测各加一个 `case`  | `'GP_Custom'`        |
| 新采集准则 | `infillSelect.m` 主 `switch` 加一个 `case` | `'UCB'` 上置信界     |

---

## 六、性能与复杂度

| 操作              | 复杂度     | 典型耗时（N≤200, Nq≈100, K=2） |
| ----------------- | ---------- | -------------------------------- |
| DACE Kriging 训练 | O(K·N³)  | < 1 s                            |
| 代理预测          | O(Nq·N²) | < 0.1 s                          |
| 2D EHVI 闭式      | O(Nq·Nf)  | < 1 ms                           |
| 相关性聚类        | O(M²)     | 可忽略（M ≤ 15）                |
| 一次外迭代        | —         | < 2 s                            |

**整体实测**（DTLZ5 M=8, D=10, maxFE=300, BatchSize=1）：约 200 轮外迭代，总耗时 1~5 分钟。Archive=300，HV≈0.0287，非支配解 83 个。

---

## 七、总结

DR_SAEA 通过**降维 + 代理 + 采样**的三段式解耦设计，为昂贵超多目标优化提供了一个理想的**模块级消融研究底座**：

1. **降维模块**用随机/相关性两种策略把 M 维目标压到 K 维，解除了代理模型的维度灾难，且保证降维仅作中间表示、不污染最终 M 维输出；
2. **代理模块**用 Kriging/RBF/Relation 三选一在降维目标上建模，自实现 RBF 与 Kriging 单/多点预测接口处理，做到零外部硬依赖；
3. **填充采样模块**用 exploitation/exploration/balanced 三种采集准则 + 2D 闭式 EHVI + 去重/多样性约束 + 回退机制，在降维空间稳健地挑选下一批评估点。

三者通过 Archive（M 维真实目标）与 Zall（K 维降维目标）两套数据流协同，构成完整的"真实评估—代理预测—智能采样"闭环，是 PlatEMO 平台上少见的**完全可插拔 SAEA 框架**。

> 本汇报基于 DR_SAEA 源码逐行分析生成（`DR_SAEA.m`、`reduceObjectives.m`、`buildSurrogate.m`、`infillSelect.m`、`computeEHVI.m`），文档版本：2026-06-16。
