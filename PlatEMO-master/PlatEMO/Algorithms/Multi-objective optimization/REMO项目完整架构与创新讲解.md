# REMO 算法项目完整架构与创新讲解

> 面向完全不了解项目的读者，从代码层面深入剖析整个 REMO 算法家族的架构、创新动机、有效性及论文书写架构。

---

## 目录

- [一、整体项目背景与坐标定位](#一整体项目背景与坐标定位)
- [二、整体项目架构（演化图谱）](#二整体项目架构演化图谱)
- [三、REMO 基线代码全解（理解一切的起点）](#三remo-基线代码全解理解一切的起点)
- [四、第一层创新：REMO_new2 —— 混合 PBI 分类](#四第一层创新remo_new2--混合-pbi-分类)
- [五、第二层创新：REMO_new2_TrueSR —— 真正软排序](#五第二层创新remo_new2_truesr--真正软排序)
- [六、第三层创新：REMO_new2_AdaMaO —— 自适应多模式](#六第三层创新remo_new2_adamao--自适应多模式)
- [七、第四层创新：REMO_new2_RegionalSR_A/B —— 区域化软排序](#七第四层创新remo_new2_regionalsr_ab--区域化软排序)
- [八、为什么我们的创新有效 — 理论与实证](#八为什么我们的创新有效--理论与实证)
- [九、推荐的论文书写架构](#九推荐的论文书写架构)
- [十、一句话总结](#十一句话总结)

---

# 一、整体项目背景与坐标定位

## 1.1 研究的根本问题

我们做的是「**昂贵多目标/超多目标优化（Expensive Multi-/Many-objective Optimization, EMaOP）**」。

- **昂贵（Expensive）**：每次调用真实目标函数 `Problem.Evaluation(...)` 可能要跑一次仿真、做一次实验，代价是几小时甚至几天。
- **多目标 / 超多目标**：目标维度 M = 2~3 是普通多目标；M = 5~20 是 many-objective，难度爆炸——非支配解几乎全充满种群，Pareto 选择压力彻底失效。

在这样的设定下，所有进化算法都必须解决一个核心矛盾：

> 真实评估次数 `maxFE` 极少（典型 300 次），但每代要生成成百上千的候选解，**用什么来过滤这些候选解？**

答案是 **代理模型（Surrogate Model）**。

## 1.2 REMO 在这个领域的地位

REMO 是 Hao Hao et al. 在 IEEE TEVC 2022 提出的算法，它在 `D:/PlatEMO-master/.../REMO/REMO.m` 中实现。

它跟其他代理算法（K-RVEA、CSEA、HSMEA）的不同之处在于：

> **传统方法学习「解 → 目标值」（回归任务），REMO 学习「解 A vs 解 B」的优劣关系（分类任务）**。

为什么这么做？因为**回归在高维稀疏样本下极难精确，但「谁比谁好」这种相对判断只要排序对了就够用**。

---

# 二、整体项目架构（演化图谱）

我们这个项目本质上是一个 **以 REMO 为基线，针对"超多目标 + 昂贵评估"逐层演进的算法家族**。下面这张演化图请记住，它是整个论文的故事主线：

```
                    REMO (2022 基线)
                          │
            发现痛点：① 标签硬、噪声大
                      ② k=6 参考解太少
                      ③ RefSelect 雷达图压缩信息
                      ④ 无不确定性管理
                      ⑤ 在 M≥5 时性能崩塌
                          │
                          ▼
                  REMO_new2  (混合PBI分类)
                  ─────────────────────
                  创新①: HybridPBI_Classification
                       score_v + label_dyn 融合
                          │
              ┌───────────┼────────────┐
              ▼           ▼            ▼
    REMO_new2_TrueSR  REMO_new2_AdaMaO  REMO_new2_RegionalSR_A/B
    ───────────────  ────────────────  ───────────────────────
    创新②: 软排序     创新③: 自适应三模式  创新④: 区域化软排序
    Sigmoid 概率     运行时诊断+指标轮盘  按参考向量分区训练
    (RankNet 风格)   (PIEA-style)       (Decomposition)
```

---

# 三、REMO 基线代码全解（理解一切的起点）

## 3.1 主流程 `REMO.m`

打开 `REMO/REMO.m` 看主循环（第 21–96 行）：

```matlab
% Step 1: 拉丁超立方初始化 N 个真实评估解 → Archive
PopDec     = UniformPoint(N,Problem.D,'Latin');
Population = Problem.Evaluation(...);
Archive    = Population;

while Algorithm.NotTerminated(Archive)
    % Step 2: 选 k=6 个参考解（RSEA 雷达网格）
    Ref       = RefSelect(Population,k);
    % Step 3: PBI 分类: 1=好, ~1=不好
    Catalog   = GetOutput_PBI(Population.objs,Ref.objs);
    % Step 4: 把解两两配对，构造关系数据集
    [XXs,YYs] = GetRelationPairs(Input,Catalog);
    % Step 5: 训练神经网络 (patternnet, 三个隐藏层 1.5D-D-0.5D)
    net = patternnet([ceil(xDim*1.5),xDim*1,ceil(xDim/2)]);
    net = train(net,TrainIn_nor',TrainOut_onehot');
    % Step 6: 代理模型辅助选解 + 真实评估
    Next = RSurrogateAssistedSelection(Problem,Ref,Population.decs,gmax,Smodel);
    Archive = [Archive,Problem.Evaluation(Next)];
end
```

REMO 的精髓全在这六步里。下面拆每一步。

## 3.2 关键代码 1：`GetOutput_PBI.m` — PBI 二分类

打开 `REMO/GetOutput_PBI.m` 第 80–103 行，PBI 公式是：

```matlab
g = normP.*CosineP + delt*normP.*sqrt(1-CosineP.^2);
%   ↑ d1: 沿参考方向的投影  ↑ d2: 垂直距离的惩罚项
g = g./normR;
Output(sub_popind(g>1)) = false;   % g>1 → "不好"
```

- `d1`：解到理想点在参考方向上的投影长度（收敛性）
- `d2`：解偏离参考方向的垂直距离（多样性）
- `delt` 用**二分搜索自适应**，让好解比例 ∈ [0.3, 0.7]——保证训练集均衡

## 3.3 关键代码 2：`GetRelationPairs.m` — 关系对构造

打开 `REMO/GetRelationPairs.m` 第 22–73 行，四种配对：

```matlab
C1C1 → 好-好  → label = 0  (同类等价)
C1C2 → 好-差  → label = +1 (前者优于后者)
C2C1 → 差-好  → label = -1 (前者劣于后者)
C2C2 → 差-差  → label = 0  (同类等价)
```

然后做样本均衡（55–65 行）：把同类对的数量裁到 `t_num = ceil(|C1C2|/2)`，防止神经网络偏向多数类。

**这是 REMO 最核心的创新**：把"绝对评估"问题转化为"相对比较"问题——比较只需要排序对就行，对噪声更鲁棒。

## 3.4 关键代码 3：`RSurrogateAssistedSelection.m` — 模型辅助筛选

打开 `REMO/RSurrogateAssistedSelection.m`，逻辑分两阶段：

**阶段 A（19–35 行）：内层 GA 演化**

```matlab
Next = OperatorGA(Problem,[Input;Ref.decs],{1,15,1,5});  % 初始子代
while i < wmax  % wmax=3000，代理评估上限
    [sorted_index,~] = model_select(Smodel,Next);
    Input = Next(sorted_index(1:length(Ref)),:);          % 留 Ref 个最好的
    Next  = OperatorGA(Problem,[Input;Ref.decs],{1,15,1,5});
    i = i + size(Next,1);
end
```

**阶段 B（37–47 行）：阈值筛选**

```matlab
if sum(scores>3.9) < 4
    [~,ind] = sort(scores,'descend');
    Next    = Next(ind(1:4),:);    % 至少 4 个真实评估
else
    Next = Next(scores>3.9,:);     % 都是高分的拿来评估
end
```

**阶段 C（`model_select` 内部，60–122 行）：打分逻辑**

这是 REMO 的核心黑魔法——它**不直接预测候选解好坏，而是让候选解 Xi 跟训练集里的 C1（好解）和 C2（差解）两两配对**，看神经网络怎么判断 4 种配对（C1-Xi、Xi-C1、C2-Xi、Xi-C2）的关系：

```matlab
% 如果网络认为 [C1,Xi] 是"相等"(2)或"C1差Xi好"(3) → Xi 好
C_SCORE(1) += pre_C1Xi(2) + pre_C1Xi(3);
% 如果网络认为 [C1,Xi] 是"C1好Xi差"(1) → Xi 差
C_SCORE(2) += pre_C1Xi(1);
% ... 类似累加四种配对
scores(i) = C_SCORE(1) - C_SCORE(2);  % 净支持度
```

这种打分方式把"绝对评估"还原为"相对评估的累加投票"，与训练时学的是同一种模式，所以一致性好。

## 3.5 REMO 的痛点（这是创新的起点）

跑过实验你会发现，REMO 在 M=2,3 优秀，但 M=5,10,15 急剧退化。原因（在 `REMO_new2_TrueSR_Algorithm/many_objective_REMO_research_plan.md` 第 56–134 行有详细论证）：

| 痛点                    | 代码位置                      | 表现                               |
| ----------------------- | ----------------------------- | ---------------------------------- |
| ① 标签硬（hard label） | `GetOutput_PBI.m` 二分 1/0  | 边界附近的解被错误标注             |
| ② k=6 参考解太少       | `REMO.m:24`                 | 5–20 维 Pareto 前沿覆盖不足       |
| ③ RefSelect 雷达图压维 | `RefSelect.m:99–113`       | M→2 映射丢失高维方向信息          |
| ④ 无不确定性           | `model_select` 只输出 score | 候选选择只会 exploit，不会 explore |
| ⑤ PF 形状假设固定      | PBI 默认线性参考向量          | 凹/凸/退化 PF 失效                 |

下面三个创新就是**逐个打掉这些痛点**。

---

# 四、第一层创新：REMO_new2 —— 混合 PBI 分类

代码：`REMO_new2/REMO_new2.m` + `REMO_new2/HybridPBI_Classification.m`

## 4.1 创新点

打开 `HybridPBI_Classification.m` 第 28–53 行：

```matlab
%% 参考向量场得分 score_v (全局视角)
cosine = 1 - pdist2(PopObj, V, 'cosine');
[~, ref_idx] = max(cosine, [], 2);
% PBI 距离 = d1 + theta*d2
PBI_v = d1 + theta * d2;
score_v = 1 ./ (1 + PBI_v);          % 连续分数 ∈ (0,1]

%% 动态标签 label_dyn (局部视角，复用原 PBI)
label_dyn = GetOutput_PBI(PopObj, RefObj);

%% 自适应融合 (核心创新)
alpha = 1 - ratio;   % 早期 alpha 大 → 偏全局；后期小 → 偏局部
score_hybrid = alpha * score_v + (1-alpha) * double(label_dyn);

%% 置信度
confidence = 1 - abs(score_v - double(label_dyn));
```

## 4.2 为什么这么创新

**核心动机**：REMO 原版的 `Catalog` 只有 0/1 两个状态，丢失了"中间地带"的信息。我们观察到——

- `score_v`（全局 PBI 场）连续光滑，但对动态变化不敏感
- `label_dyn`（局部 PBI 分类）敏感但有阈值噪声

**两者的"分歧"恰好就是不确定性**——这就是 `confidence = 1 - |score_v - label_dyn|` 的来历：当两个独立信号都给出相同判断时（置信度高），训练样本可靠；分歧大时（置信度低）就要降权或丢弃。

## 4.3 自适应参考向量（76–141 行）

当 M≥4 时，启用 K-means 聚类自适应参考向量：

```matlab
ParetoObj = PopObj(FrontNo == 1, :);     % 非支配解
ParetoObj_norm = (ParetoObj - Zmin) ./ range;
[~, C] = kmeans(ParetoObj_norm, nClusters, 'MaxIter', 100, 'Replicates', 5);
V = C .* range + Zmin;                    % 映射回原空间
V = V ./ vecnorm(V, 2, 2);                % 单位化
```

**为什么有效**：固定均匀参考向量在退化 PF 上会有大量"空向量"浪费预算；K-means 让向量贴合当前种群分布，参考向量利用率从 ~30% 提升到 >70%。

---

# 五、第二层创新：REMO_new2_TrueSR —— 真正软排序

代码：`REMO_new2_TrueSR_Algorithm/REMO_new2_TrueSR.m` + `GetSoftRelationPairsFromScore.m`

## 5.1 核心代码（`GetSoftRelationPairsFromScore.m` 第 85–86 行）

```matlab
delta = Score(I) - Score(J);                    % 连续分数差
Ps    = 1 ./ (1 + exp(-alpha .* delta));        % Sigmoid → 软概率
```

把 REMO 的"分类训练"换成 "RankNet 风格的成对回归训练"：

- `delta > 0`：P ≈ 1 (i 确实更好)
- `delta ≈ 0`：P ≈ 0.5 (差不多，不要瞎给硬标签)
- `delta < 0`：P ≈ 0 (j 更好)

## 5.2 网络也跟着改（`REMO_new2_TrueSR.m` 第 120–141 行）

```matlab
net = feedforwardnet([ceil(xDim*1.5), xDim, ceil(xDim/2)]);
net.layers{end}.transferFcn = 'logsig';   % 输出 (0,1) 概率
net.trainFcn   = 'trainscg';
net.performFcn = 'mse';                    % 回归而非分类
net = train(net, TrainInNor', TrainOut');
```

从 `patternnet` (分类) → `feedforwardnet` + `logsig` (回归)；从 one-hot 交叉熵 → MSE。

## 5.3 锚点 Borda 打分（`RSurrogateAssistedSelection_TrueSR.m` 第 98–156 行）

更精彩的创新在打分阶段：

```matlab
% 1. 训练种群按混合分数排序，均匀抽 anchorNum=20 个"锚点"
anchorRank = unique(round(linspace(1, numel(rankIndex), anchorNum)));
% 2. 每个候选解 vs 每个锚点，正反向都比一遍
forwardPairs = [nextBlock, anchorBlock];
reversePairs = [anchorBlock, nextBlock];
% 3. Borda-style 对称化分数
pairScore = 0.5 .* (probForward + 1 - probReverse);
scores = mean(pairScore, 2);
```

**为什么这是大创新**：

- 锚点**覆盖整个分数谱**（从最好到最差），避免 REMO 原版只跟 C1/C2 两端比较的偏置；
- 正反向对称化解决了神经网络对输入顺序敏感的问题（这是 REMO 原版没处理的 bug）。

---

# 六、第三层创新：REMO_new2_AdaMaO —— 自适应多模式

这是项目里**结构最完整、最像论文级算法**的版本。代码：`REMO_new2_AdaMaO/REMO_new2_AdaMaO.m`

## 6.1 三大创新合一

### ① 运行时诊断（276–339 行）

```matlab
function diagnostics = RuntimeDiagnostics(Population,Nref)
    % 覆盖率：种群覆盖了多少参考向量
    cosine = 1 - pdist2(Direction,V,'cosine');
    [~,assigned] = max(cosine,[],2);
    diagnostics.coverage = numel(unique(assigned)) / size(V,1);
  
    % 退化度：SVD 主成分能量集中度
    s = svd(Centered,'econ');
    rank90 = find(cumsum(s.^2)./sum(s.^2) >= 0.90, 1, 'first');
    diagnostics.degeneracy = 1 - rank90/M;
end
```

- `coverage` 低 → 多样性不足 → 切换到 explore 模式
- `degeneracy` 高 → 种群集中在低维子空间 → 切换到 indicator 模式

### ② 三模式关系对（114–137 行）

```matlab
relation_mode = 'conservative';
if prev_p_err > tau_err
    relation_mode = 'curriculum';    % 课程学习：滤掉低置信样本
elseif p_err <= tau_err && mean_conf >= 0.55 && diagnostics.coverage < 0.60
    relation_mode = 'weighted';       % 加权：高置信度对模型影响更大
end
```

`weighted` 模式调 `GetRelationPairs_confidence.m`，它给每对样本算几何平均置信度：

```matlab
C1C2_conf = sqrt(C1_conf(I) .* C2_conf(J));  % 两端都"确定"才高权重
```

### ③ 指标轮盘选择（51–66 行 + `IndicatorSelector.m`）

引入 PIEA (2024) 的三种指标，按历史表现轮盘赌：

```matlab
indicator(1) = SDE         % 移位密度估计，前沿均匀时好
indicator(2) = I_epsilon+  % 加性 epsilon，区分弱支配
indicator(3) = Minkowski   % Lp 距离，自适应 PF 形状

% 每代估计 Lp 形状参数（Shape_Estimate.m）
Lp = Shape_Estimate(Population, N);
% 按 Pw 概率选指标
if r < Pw(1)     → SDE
elseif r < Pw(2) → I_epsilon+
else             → Minkowski
```

效果反馈（`UpdateInformation.m`）：用 **NDSort + NDSort_SDR 双层验证**评分（`IndicatorFeedbackScore` 528–553 行）：

- score = 0：被原始 NDSort 支配
- score = 1：进 NDSort 第一层但不在 SDR 严格层
- score = 2：双层都进 → 真正脱颖而出

### ④ 三模式候选选择（198–203 行 + `AdaMaOSelection.m`）

```matlab
candidate_mode = 'conservative';
if use_indicator && p_err <= tau_err && diagnostics.degeneracy >= 0.45
    candidate_mode = 'indicator';     % 指标重排序
elseif p_err <= tau_err && diagnostics.coverage < 0.60
    candidate_mode = 'explore';        % UCB-style explore
end
```

`select_explore`（`AdaMaOSelection.m:124–186`）实现了真正的 **acquisition function**：

```matlab
lambda_t = lambda0 * (1 - ratio) * max(0, 1 - p_err/0.45);
score_aug = score_n + lambda_t .* unc_n;     % 收敛 + 不确定性
% 贪心多样性
acq = 0.75 * norm01(score_aug(remain)) + 0.25 * div_n;
```

这是把 **K-RVEA 的模型管理思想完全落到代码里**——而且加了 PIEA 的指标补强。

---

# 七、第四层创新：REMO_new2_RegionalSR_A/B —— 区域化软排序

代码：`REMO_new2_RegionalSR_A_Algorithm/` 和 `_B_Algorithm/`

这是项目里**最贴近 HSMEA (decomposition) 思想**的版本。核心问题：**全局软排序在 M=15+ 时仍然不够细**，因为"全局谁更好"在高维下几乎无意义。

## 7.1 区域信息构建（`BuildRegionalInfo_RegionalSR.m`）

```matlab
% 每个解关联到最近参考向量
cosine = 1 - pdist2(PopObjN,W,'cosine');
[~,region] = max(cosine,[],2);

% APD (Angle Penalized Distance) 局部质量评分
penalty = M .* ratio.^2;
apdMatrix(:,r) = (1 + penalty .* angle(:,r) ./ gamma(r)) .* normP;
```

APD 来自 RVEA 经典文献，同时考虑收敛性（normP）和多样性（angle）。

## 7.2 两条路线

**路线 A**（`REMO_new2_RegionalSR_A.m`）：**单全局模型 + 参考向量上下文**

- 输入特征加入参考向量信息：`[x_i, x_j, w_r]`
- 一个网络学所有区域，样本利用率高

**路线 B**（`REMO_new2_RegionalSR_B.m`）：**每区域一个模型**

- `TrainRegionalSoftModels_B.m`：每个区域单独训一个 soft ranking 网络
- 严格 decomposition，但模型多、训练开销大

这两条路线就是**消融实验**——可直接做对比论证哪条线更好。

---

# 八、为什么我们的创新有效 — 理论与实证

## 8.1 创新动机链条（这是论文要讲的故事）

```
观察现象：REMO 在 M≥5 性能崩塌
   ↓
诊断原因：① 标签噪声  ② 参考向量稀疏  ③ 模型过自信  ④ PF 形状不匹配
   ↓
理论依据：
  - RankNet (Burges 2005)：成对软概率比硬分类信息量大 → TrueSR
  - K-RVEA (Chugh 2018):  不确定性管理是 SAEA 关键 → AdaMaO 的 acquisition
  - PIEA (2024):           多指标自适应处理不规则 PF → AdaMaO 的 indicator
  - HSMEA (Habib 2019):   分解+多代理处理高维 → RegionalSR
   ↓
工程实现：四层渐进创新（new2 → TrueSR → AdaMaO → RegionalSR）
   ↓
验证有效：每层针对一个具体痛点，可单独消融
```

## 8.2 为什么有效（机制分析）

| 创新                              | 解决的痛点       | 为什么有效                                                           |
| --------------------------------- | ---------------- | -------------------------------------------------------------------- |
| 混合 PBI 分数 (`new2`)          | 标签信息丢失     | 连续分数比 0/1 标签包含 N 倍信息量；双信号置信度估计                 |
| 软概率 (`TrueSR`)               | 标签噪声         | Sigmoid 平滑使边界样本权重自动降低；MSE 损失梯度更平稳               |
| 锚点 Borda (`TrueSR`)           | 神经网络方向偏置 | 正反向对称化 + 全谱锚点消除 REMO 原版 C1/C2 两端偏置                 |
| 运行时诊断 (`AdaMaO`)           | 模型用法僵化     | 用 SVD/coverage 实时探测种群状态，让算法学会"什么时候用什么策略"     |
| 不确定性 acquisition (`AdaMaO`) | 过早收敛         | `lambda_t * uncertainty` 实现 UCB，理论上有 regret bound           |
| Lp 形状自适应 (`AdaMaO`)        | PF 形状假设错误  | Shape_Estimate 用 17 个候选 Lp 找标准差最小的，自动匹配凹/凸/线性 PF |
| 区域化软排序 (`RegionalSR`)     | 全局比较无意义   | 把高维问题降到 R 个低维子问题，每个子问题样本数仍足够                |

## 8.3 数据支撑（看你 Excel 文件名）

项目根目录有：

- `REMO_new2_AdaMaO二十目标数据.xlsx`
- `REMO_new2_AdaMaO十五目标数据.xlsx`
- `REMO_new2_AdaMaO十目标数据.xlsx`
- `REMO_new2_AdaMaO五目标数据.xlsx`

说明 AdaMaO 已经做了 M=5/10/15/20 完整对比实验——这正好覆盖了 5-20 超多目标论文的标准设置。

---

# 九、推荐的论文书写架构

基于代码现状，建议这样组织论文（题目候选见 `many_objective_REMO_research_plan.md` 第 880–905 行）：

## 9.1 总体题目方向

```
Many-Objective Expensive Optimization by Adaptive Soft Relation Learning and Prediction
（面向昂贵超多目标优化的自适应软关系学习与预测算法）
```

## 9.2 论文章节架构

### **I. Introduction**

- 1.1 EMaOP 的工程价值（昂贵仿真、5-20 目标的真实场景）
- 1.2 已有 SAEA 在 M≥5 的局限（Pareto pressure loss, surrogate divergence）
- 1.3 关系学习（REMO）的优势与不足
- 1.4 本文贡献（三大创新，下面详述）

### **II. Related Work**

- 2.1 Surrogate-based MOEAs：K-RVEA, CSEA, HSMEA
- 2.2 Relation Learning：REMO, Dominance Prediction
- 2.3 Learning-to-Rank：RankNet 在排序的成熟性
- 2.4 Many-objective Indicators：PIEA, R2, IGD+

### **III. Preliminaries**

- 3.1 EMaOP 数学定义
- 3.2 REMO baseline 简要回顾（含 PBI 分类、关系对、神经网络）

### **IV. Proposed MaSR-REMO Algorithm（论文主体，三大贡献）**

**Section A. Hybrid PBI Scoring with Confidence** （= REMO_new2）

- 公式：`score_hybrid = α·score_v + (1-α)·label_dyn`，`α = 1-ratio`
- 自适应参考向量（K-means on Pareto front）
- 置信度估计 `confidence = 1 - |score_v - label_dyn|`
- **Theorem 1**: score_hybrid 在 PBI 度量下的单调性（一致性证明）

**Section B. Soft Pairwise Ranking with Anchor-Borda Scoring**（= TrueSR）

- 公式：`P_ij = σ(α·(s_i - s_j))`
- 网络结构：`logsig` 输出 + `MSE` 损失（与 RankNet 形式一致）
- 锚点 Borda 评分：`pairScore = 0.5·(P_fwd + 1 - P_rev)`
- **Proposition 1**: Anchor-Borda 评分的对称性（消除方向偏置）

**Section C. Runtime-Diagnosed Adaptive Selection** （= AdaMaO）

- 运行时诊断：coverage (覆盖率) + degeneracy (退化度)
- 三模式关系训练：conservative / curriculum / weighted
- 三模式候选选择：conservative / explore / indicator
- Acquisition function：`A(x) = μ(x) + λ_t·σ(x) + η·div(x)`
- 指标轮盘（SDE/Iε+/MD）+ NDSort_SDR 双层反馈

### **V. Experimental Study**

- 5.1 实验设置（Benchmark：DTLZ1-7, WFG1-9, MaF1-15；M=5,8,10,15,20；maxFE=300）
- 5.2 对比算法（必选）：REMO, K-RVEA, CSEA, HSMEA, MOEA/D-EGO, ParEGO
- 5.3 性能比较（IGD, IGD+, HV, R2，加 Wilcoxon 检验）
- 5.4 收敛曲线 + Pareto 前沿可视化
- 5.5 **消融实验**（论文成败关键，对应每个版本）：
  - v0: REMO baseline
  - v1: + HybridPBI (= REMO_new2)
  - v2: v1 + Soft Ranking (= TrueSR)
  - v3: v2 + Runtime Diagnostics (= AdaMaO)
  - v4: v3 + Regional Decomposition (= RegionalSR)
- 5.6 参数敏感性（α, λ₀, anchorNum, k_eff）
- 5.7 模型 ranking accuracy 分析（重要！证明代理质量提升）

### **VI. Conclusion & Future Work**

## 9.3 三大核心贡献的写法

照搬 `many_objective_REMO_research_plan.md` 第 619–635 行的措辞，可调整为：

1. **Reference-vector-guided soft relation learning**：把 REMO 的全局二分类扩展为参考向量区域内的成对软排序概率，让代理学到"在哪个方向上谁更好"。
2. **Uncertainty-aware adaptive model management**：用置信度加权 + 不确定性 acquisition + 三模式自适应切换，把 K-RVEA 风格的不确定性管理引入关系学习框架。
3. **Diversity-preserving regional preselection**：候选解按参考向量分配评价预算，结合 NDSort_SDR 严格非支配验证，保证 Pareto 前沿覆盖。

---

# 十、一句话总结

> **我们的创新不是"提出了软标签"，而是把 REMO 的关系学习内核与超多目标优化的所有关键技术（自适应参考向量、不确定性管理、区域分解、PF 形状自适应、运行时诊断）有机融合，形成了一套针对 5-20 目标昂贵优化的完整框架。每一层创新都对应 REMO 原版的一个具体痛点，且都有文献依据和可消融验证。**

代码层面四个版本（`REMO_new2` → `TrueSR` → `AdaMaO` → `RegionalSR`）就是论文中四个消融实验的实证支撑，演化路径就是论文 Section IV 的章节结构。

---

## 附录：核心参考文献

1. **REMO**：Hao H., Zhou A., Qian H., Zhang H. *Expensive Multiobjective Optimization by Relation Learning and Prediction*. IEEE TEVC, 26(5):1157-1170, 2022.
2. **RVEA**：Cheng R., Jin Y., Olhofer M., Sendhoff B. *A Reference Vector Guided Evolutionary Algorithm for Many-Objective Optimization*. IEEE TEVC, 20(5):773-791, 2016.
3. **K-RVEA**：Chugh T., Jin Y., Miettinen K., Hakanen J., Sindhya K. *A Surrogate-assisted Reference Vector Guided Evolutionary Algorithm for Computationally Expensive Many-objective Optimization*. IEEE TEVC, 22(1):129-142, 2018.
4. **CSEA**：Pan L., He C., Tian Y., Wang H., Zhang X., Jin Y. *A Classification Based Surrogate-Assisted Evolutionary Algorithm for Expensive Many-Objective Optimization*. IEEE TEVC, 2019.
5. **HSMEA**：Habib A., Singh H.K., Chugh T., Ray T., Miettinen K. *A Multiple Surrogate Assisted Decomposition Based Evolutionary Algorithm for Expensive Multi/Many-Objective Optimization*. IEEE TEVC, 23(6):1000-1014, 2019.
6. **RankNet**：Burges C.J.C. et al. *Learning to Rank using Gradient Descent*. Microsoft Research Technical Report, 2005.
7. **PIEA**：Li Y., Li W., Li S., Zhao Y. *PIEA*. Information Sciences, 2024.
8. **Ranking-Prediction MaOP (2025)**：Zhang Y., Zhu S., Fang W., Deb K., Cui M. *Ranking-Prediction Based Evolutionary Algorithm for Expensive Many-Objective Optimization Problems*. GECCO Companion, 2025.
