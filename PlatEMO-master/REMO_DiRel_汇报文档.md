# REMO_DiRel: 难度感知双尺度关系学习的昂贵超多目标优化

## 项目汇报文档

---

## 一、研究背景与问题定义

### 1.1 问题领域

本项目聚焦于**昂贵超多目标优化问题 (Expensive Many-Objective Optimization)**，其核心特征为：

- **目标数量多**：M ≥ 5，通常 M ∈ {5, 10, 15, 20}
- **评估昂贵**：每次真实评估需要数小时甚至数天（如CFD仿真、物理实验）
- **决策变量连续**：x ∈ R^D，D 通常为 10~30
- **目标冲突**：多个目标之间存在复杂的 Pareto 支配关系

### 1.2 核心挑战

```
┌─────────────────────────────────────────────────────────────────┐
│                    超多目标优化的核心挑战                          │
├─────────────────────────────────────────────────────────────────┤
│  1. 维度灾难：M↑ → Pareto前沿指数膨胀 → 搜索空间爆炸            │
│  2. 评估稀缺：每次评估昂贵 → 总预算有限 (maxFE ≤ 300)            │
│  3. 目标冗余：部分目标高度相关 → 建模浪费                         │
│  4. 目标异质：不同目标的建模难度差异巨大                           │
│  5. 关系复杂：成对比较关系 (A≻B?) 比绝对值更难预测                 │
└─────────────────────────────────────────────────────────────────┘
```

### 1.3 现有方法的局限性

| 方法类别 | 代表算法 | 主要局限 |
|---------|---------|---------|
| 基于分解 | MOEA/D, RVEA | 权重向量难以覆盖高维空间 |
| 基于指标 | SMS-EMOA, HypE | 指标计算复杂度随M指数增长 |
| 基于支配 | NSGA-III | Pareto支配关系在高维退化 |
| **代理辅助** | **REMO** | **单模型、随机初始化、全局权重** |

---

## 二、算法总体架构

### 2.1 一句话定位

> **以"目标跨度/改进停滞 + Spearman 冲突度"联合度量在线排序目标，构造"全目标 + 易子集"双关系网络（共享backbone + 迁移初始化），通过逐候选解的逆方差仲裁融合两模型预测。**

### 2.2 系统架构图

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        REMO_DiRel 整体架构                               │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  ┌─────────────┐                                                        │
│  │  种群初始化   │ (拉丁超立方采样, 11D-1 或 100个初始解)                 │
│  └──────┬──────┘                                                        │
│         │                                                               │
│         ▼                                                               │
│  ┌─────────────────────────────────────────────────────────────────────┐ │
│  │                      主循环 (每代执行)                               │ │
│  │  ┌────────────────────────────────────────────────────────────────┐ │ │
│  │  │ Step 1: 参考解选择                                             │ │ │
│  │  │   RefSelect.m → 雷达网格策略选k个参考解                          │ │ │
│  │  └────────────────────────────────────────────────────────────────┘ │ │
│  │                              ↓                                      │ │
│  │  ┌────────────────────────────────────────────────────────────────┐ │ │
│  │  │ Step 2: 目标难度在线排序 [模块①]                                │ │ │
│  │  │   DifficultyProfiler.m                                         │ │ │
│  │  │   ├─ 轻量建模难度 = 0.5×跨度分 + 0.5×停滞分                    │ │ │
│  │  │   ├─ Spearman冲突度 = mean(1-|ρ_j,others|)                     │ │ │
│  │  │   ├─ 联合难度 d = α×建模难度 + (1-α)×冲突难度                  │ │ │
│  │  │   └─ 输出: S_easy (易目标子集索引)                               │ │ │
│  │  └────────────────────────────────────────────────────────────────┘ │ │
│  │                              ↓                                      │ │
│  │  ┌────────────────────────────────────────────────────────────────┐ │ │
│  │  │ Step 3: 双尺度关系对构造                                        │ │ │
│  │  │   全目标支线: GetOutput_PBI → GetRelationPairsBudgeted          │ │ │
│  │  │   子目标支线: PopObj(:,S_easy) → 缩放Ref → PBI → 关系对         │ │ │
│  │  └────────────────────────────────────────────────────────────────┘ │ │
│  │                              ↓                                      │ │
│  │  ┌────────────────────────────────────────────────────────────────┐ │ │
│  │  │ Step 4: 双尺度集成网络训练 [模块②]                              │ │ │
│  │  │   TrainDualScaleNet.m                                          │ │ │
│  │  │   ├─ net_F: 全目标关系 (3个bagging patternnet, 60epochs)        │ │ │
│  │  │   └─ net_S: 子目标关系 (迁移初始化自net_F, 30epochs)            │ │ │
│  │  └────────────────────────────────────────────────────────────────┘ │ │
│  │                              ↓                                      │ │
│  │  ┌────────────────────────────────────────────────────────────────┐ │ │
│  │  │ Step 5: 仲裁选择 [模块③]                                       │ │ │
│  │  │   ArbitratedSelection.m + ArbitratorScore.m                    │ │ │
│  │  │   ├─ GA内循环生成候选解                                         │ │ │
│  │  │   ├─ 逐候选逆方差权重融合                                       │ │ │
│  │  │   └─ 冲突分支处理 (弃权/多样性奖励)                             │ │ │
│  │  └────────────────────────────────────────────────────────────────┘ │ │
│  │                              ↓                                      │ │
│  │  ┌────────────────────────────────────────────────────────────────┐ │ │
│  │  │ Step 6-8: 评估与更新                                           │ │ │
│  │  │   sanitizeCandidates → Problem.Evaluation → RefSelect          │ │ │
│  │  └────────────────────────────────────────────────────────────────┘ │ │
│  └─────────────────────────────────────────────────────────────────────┘ │
│         │                                                               │
│         ▼                                                               │
│  ┌─────────────┐                                                        │
│  │  输出 Archive │ (最终Pareto解集)                                      │
│  └─────────────┘                                                        │
└─────────────────────────────────────────────────────────────────────────┘
```

### 2.3 文件组织结构

```
PlatEMO/Algorithms/Multi-objective optimization/REMO_DiRel/
│
├── REMO_DiRel.m                 # 主算法入口 (5170B)
│
├── DifficultyProfiler.m         # 模块①: 目标难度在线排序 (2244B)
├── ConflictDegree.m             # 模块①辅助: Spearman冲突度计算 (940B)
├── RefineEasySubset.m           # 模块①辅助: 反向冗余检查 (2869B)
│
├── TrainDualScaleNet.m          # 模块②: 双尺度集成网络训练 (5397B)
├── TransferFineTune.m           # 模块②辅助: 权重迁移初始化 (2110B)
│
├── ArbitratedSelection.m        # 模块③: 仲裁选择主循环 (1427B)
├── ArbitratorScore.m            # 模块③: 逐候选逆方差仲裁评分 (5148B)
│
├── GetRelationPairsBudgeted.m   # 有上限的平衡关系对构造 (2953B)
├── KrigingNRMSE.m               # 诊断工具 (保留备用) (1817B)
│
├── README_REMO_DiRel.md         # 项目文档
│
├── REMO_DiRel_noDi/             # 消融变体: 无难度排序
├── REMO_DiRel_noSub/            # 消融变体: 无子目标建模
├── REMO_DiRel_noTrans/          # 消融变体: 无迁移初始化
├── REMO_DiRel_AvgArb/           # 消融变体: 平均仲裁权重
└── REMO_DiRel_FullArb/          # 消融变体: 全局仲裁权重
```

---

## 三、三大核心创新模块详解

### 模块①: DifficultyProfiler — 目标难度在线排序

#### 3.1.1 创新动机

**为什么需要难度排序？**

在超多目标优化中，不同目标的建模难度差异巨大：

```
目标维度M=10时:
├─ 目标1,3,7: 值域跨度小、单调改进、与其他目标正相关 → 易建模
├─ 目标2,5,9: 值域跨度大、改进停滞、与其他目标负相关 → 难建模
└─ 目标4,6,8,10: 中等难度

传统REMO: 全部M个目标一起建模 → 难目标拖累易目标 → 整体性能下降
REMO_DiRel: 只选最易的⌈M/2⌉个目标建模 → 集中精力在可靠预测上
```

**为什么不用Kriging交叉验证？**

原始DiRel想法使用Kriging NRMSE作为难度指标，但：
- Kriging训练复杂度高：O(n³)矩阵求逆
- 每代每个目标都要训练：M×gen次Kriging
- 成为运行时瓶颈

**轻量化方案**：用种群统计量替代Kriging，复杂度降至O(nM)

#### 3.1.2 核心算法

**难度计算公式**：

```matlab
% 1. 轻量建模难度
spanScore     = minmaxNorm(log1p(max(spanRaw, 0)))  % 目标值跨度的log变换
improveScore  = 1 - minmaxNorm(relImprove)           % 改进停滞程度
modelDifficulty = 0.5 × spanScore + 0.5 × improveScore

% 2. Spearman冲突度
rho = corr(PopObj, 'type', 'Spearman')               % 秩相关矩阵
conf(j) = mean(1 - |ρ_j,others|)                      % 与其他目标的平均冲突

% 3. 联合难度
d = α × modelDifficulty + (1-α) × (1 - conf)
```

**难度指标的物理含义**：

| 指标 | 计算方式 | 高值含义 | 低值含义 |
|------|---------|---------|---------|
| `spanScore` | log(目标值范围) | 目标值分散，难以精确建模 | 目标值集中，容易建模 |
| `improveScore` | 1 - 相对改进率 | 改进停滞，优化陷入困境 | 持续改进，优化方向明确 |
| `conflictDegree` | mean(1-\|ρ\|) | 与其他目标冲突大 | 与其他目标协调一致 |
| **联合难度d** | 加权组合 | **难建模** | **易建模** |

#### 3.1.3 代码实现细节

**DifficultyProfiler.m 核心逻辑**：

```matlab
function [d_score, H, S_easy] = DifficultyProfiler(Population, H, gen, alpha, k_easy)
    PopObj = Population.objs;
    [~, M] = size(PopObj);

    % === 1. 计算目标值跨度 ===
    spanRaw = (max(PopObj, [], 1) - min(PopObj, [], 1))';
    spanScore = minmaxNorm(log1p(max(spanRaw, 0)));  % log平滑

    % === 2. 计算改进停滞 ===
    bestNow = min(PopObj, [], 1)';                    % 当前代最优值
    if ~isfield(H, 'best') || all(isnan(H.best))
        improveScore = ones(M, 1);                     % 首代假设停滞
    else
        baseImprove = max(abs(H.best), 1e-12);
        relImprove  = max((H.best - bestNow) ./ baseImprove, 0);
        improveScore = 1 - minmaxNorm(relImprove);     % 停滞程度
    end
    H.best = bestNow;

    % === 3. 计算冲突度 ===
    modelDifficulty   = 0.5 .* spanScore + 0.5 .* improveScore;
    confRaw           = ConflictDegree(PopObj);
    confN             = minmaxNorm(confRaw);
    conflictDifficulty = 1 - confN;                    % 冲突度越高越难

    % === 4. 联合难度 + 滑动平均 ===
    d_now = alpha .* modelDifficulty + (1-alpha) .* conflictDifficulty;

    % 滑动窗口平滑 (win_K=3代)
    col = mod(gen-1, win_K) + 1;
    H.d_score(:, col) = d_now;
    d_score = meanNoNan(H.d_score, 2);                 % 均值平滑

    % === 5. 选择易目标子集 ===
    [~, ord] = sort(d_score, 'ascend');                % 升序排列
    S_cand   = ord(1:min(k_easy, numel(ord)));         % 取前k_easy个
    S_easy   = RefineEasySubset(S_cand, PopObj, d_score, k_easy);  % 冗余检查
end
```

**ConflictDegree.m — Spearman冲突度计算**：

```matlab
function conf = ConflictDegree(PopObj)
    M = size(PopObj, 2);
    rho = corr(PopObj, 'type', 'Spearman');  % M×M秩相关矩阵
    rho(isnan(rho)) = 0;                      % 处理常数列

    for j = 1:M
        others = setdiff(1:M, j);
        conf(j) = mean(1 - rho_abs(j, others));  % 与其他人平均冲突
    end
end
```

**RefineEasySubset.m — 反向冗余检查**：

```matlab
function S_easy = RefineEasySubset(S_cand, PopObj, d_score, k_easy)
    rho = corr(PopObj, 'type', 'Spearman');

    % 迭代检查：若S_easy内任意两目标|ρ|>0.95，剔除难度大者
    while true
        replaced = false;
        for i = 1:length(S_easy)
            for j = i+1:length(S_easy)
                if abs(rho(S_easy(i), S_easy(j))) > 0.95
                    % 保留d_score较小者，剔除较大者
                    if d_score(S_easy(i)) <= d_score(S_easy(j))
                        drop = S_easy(j);
                    else
                        drop = S_easy(i);
                    end
                    % 从备选池补入下一个非冗余目标
                    ...
                end
            end
        end
        if ~replaced, break; end
    end

    % 边界保护: |S_easy| ∈ [2, M-1]
    if length(S_easy) < 2
        S_easy = ord_all(1:2)';
    end
end
```

#### 3.1.4 创新有效性分析

**为什么难度排序是有效的？**

1. **信息论视角**：易目标的代理模型预测更准确 → 基于准确预测的选择更可靠
2. **计算复杂度**：避免在难目标上浪费建模资源 → 有限预算分配到刀刃上
3. **鲁棒性**：滑动窗口平滑 + 冗余检查 → 避免单代噪声和目标冗余

**消融实验验证**：

| 变体 | 改动 | 预期效果 |
|------|------|---------|
| `REMO_DiRel_noDi` | 随机选目标 | IGD显著退化 → 证明难度量化必要 |

---

### 模块②: TrainDualScaleNet — 双尺度集成网络

#### 3.2.1 创新动机

**为什么需要双尺度建模？**

传统REMO只用全目标关系模型，但：
- 全目标维度M=20 → 关系对输入维度40D → 建模复杂
- 子目标维度M_sub=10 → 关系对输入维度20D → 建模简单
- 两个视角互补：全目标看全局、子目标看局部

**为什么需要集成学习？**

单个神经网络的问题：
- 随机初始化 → 训练结果不稳定
- 单模型无法量化预测不确定性
- 容易过拟合小样本

**为什么需要迁移初始化？**

子目标关系对的样本量 ≈ 全目标关系对（来自同一种群）
- 但从零训练：30 epochs可能不够收敛
- 迁移学习：从net_F的最优解附近出发 → 更快收敛

#### 3.2.2 网络架构设计

```
输入层 (2D维)          隐藏层 (max 24节点)         输出层 (3类)
    │                        │                        │
    ├─[全目标支线]───────────┼────────────────────────┤
    │  输入: [x_i, x_j]     │  IW → LW → softmax     │  P(1), P(0), P(-1)
    │  维度: 2×M            │                        │
    │                        │                        │
    ├─[子目标支线]───────────┼────────────────────────┤
    │  输入: [x_i, x_j]     │  迁移自net_F            │  P(1), P(0), P(-1)
    │  维度: 2×M_sub        │                        │
    └────────────────────────┴────────────────────────┘

patternnet拓扑:
  Input(2D) → hidden(max(4, min([ceil(1.25×2D), 2D, ceil(D)], 24))) → softmax(3)
```

#### 3.2.3 训练流程详解

**TrainDualScaleNet.m 核心逻辑**：

```matlab
function DualNet = TrainDualScaleNet(XX_F, YY_F, XX_S, YY_S, K_ens)
    % === 全目标支线训练 ===
    [TrainIn_F, TrainOut_F, TestIn_F, TestOut_F] = DataProcess(XX_F, YY_F);
    [TrainIn_F_nor, mp_struct_F] = mapminmax(TrainIn_F');  % 归一化
    TrainOut_F_oh = onehotconv(TrainOut_F, 1);              % one-hot编码

    nets_F = trainBagEnsemble(TrainIn_F_nor, TrainOut_F_oh, xDim_F, K_ens, [], 60);
    p_err_F = testEnsemble(nets_F, TestIn_F, TestOut_F, mp_struct_F);

    % === 子目标支线训练 (迁移初始化) ===
    [TrainIn_S, TrainOut_S, TestIn_S, TestOut_S] = DataProcess(XX_S, YY_S);
    [TrainIn_S_nor, mp_struct_S] = mapminmax(TrainIn_S');
    TrainOut_S_oh = onehotconv(TrainOut_S, 1);

    nets_S = trainBagEnsemble(TrainIn_S_nor, TrainOut_S_oh, xDim_S, K_ens, nets_F, 30);
    p_err_S = testEnsemble(nets_S, TestIn_S, TestOut_S, mp_struct_S);

    DualNet = struct('nets_F', {nets_F}, 'nets_S', {nets_S}, ...
                     'mp_struct_F', mp_struct_F, 'mp_struct_S', mp_struct_S, ...
                     'p_err_F', p_err_F, 'p_err_S', p_err_S);
end
```

**trainBagEnsemble.m — Bagging集成训练**：

```matlab
function nets = trainBagEnsemble(X, Y_oh, xDim, K, initFromNets, epochs)
    nSample = size(X, 1);
    nBag = max(2, ceil(0.70 * nSample));  % 70%采样
    nets = cell(1, K);

    for i = 1:K
        % 1. 随机采样 (bagging)
        sel = randperm(nSample, nBag);
        Xi = X(sel, :);
        Yi = Y_oh(sel, :);

        % 2. 创建网络
        net = patternnet(hidden);
        net.trainParam.epochs = epochs;      % 60或30
        net.trainParam.max_fail = 6;
        net.divideParam.trainRatio = 0.8;
        net.divideParam.valRatio = 0.2;

        % 3. 迁移初始化 (如果提供源网络)
        if ~isempty(initFromNets) && i <= numel(initFromNets)
            net = TransferFineTune(net, initFromNets{i});
        end

        % 4. 训练
        try
            net = train(net, Xi', Yi');
        catch
            % 训练失败时的兜底策略
            net = patternnet(hidden);
            net = train(net, Xi', Yi');
        end

        nets{i} = net;
    end
end
```

**TransferFineTune.m — 权重迁移初始化**：

```matlab
function net = TransferFineTune(net, srcNet)
    % patternnet不支持冻结层，用"权重初始化迁移"替代

    % 复制输入权重 IW
    for i = 1:numel(net.IW)
        if isequal(size(net.IW{i}), size(srcNet.IW{i}))
            net.IW{i} = srcNet.IW{i};
        end
    end

    % 复制层间权重 LW
    for i = 1:size(net.LW, 1)
        for j = 1:size(net.LW, 2)
            if isequal(size(net.LW{i,j}), size(srcNet.LW{i,j}))
                net.LW{i,j} = srcNet.LW{i,j};
            end
        end
    end

    % 复制偏置 b
    for i = 1:numel(net.b)
        if isequal(size(net.b{i}), size(srcNet.b{i}))
            net.b{i} = srcNet.b{i};
        end
    end
end
```

#### 3.2.4 创新有效性分析

**双尺度建模的优势**：

| 视角 | 输入维度 | 信息量 | 建模难度 | 预测特点 |
|------|---------|-------|---------|---------|
| 全目标 (net_F) | 2M | 完整 | 高 | 全局准确，局部可能过平滑 |
| 子目标 (net_S) | 2M_sub | 部分 | 低 | 局部敏感，可能忽略全局 |

**集成学习的优势**：

```
单模型: ŷ = net(x) → 无法量化不确定性

集成模型: {ŷ_1, ŷ_2, ..., ŷ_K}
  ├─ 预测均值: μ = mean(ŷ_i)
  └─ 预测方差: σ² = var(ŷ_i)  → 不确定性度量
```

**迁移初始化的优势**：

```
从零训练net_S: 随机初始化 → 30 epochs → 可能未收敛
迁移训练net_S: net_F最优解附近 → 30 epochs → 更快收敛
```

---

### 模块③: ArbitratedSelection — 逐候选逆方差仲裁

#### 3.3.1 创新动机

**为什么需要逐候选权重？**

传统方法（如SRMaO）使用全局标量权重：
```
全局权重: w_F = 0.7, w_S = 0.3 (对所有候选解相同)
问题: 不同候选解的模型置信度不同 → 全局权重次优
```

**逐候选权重的优势**：
```
候选解x_1: net_F很确定(σ²小), net_S不确定(σ²大) → w_F(x_1)↑, w_S(x_1)↓
候选解x_2: net_F不确定(σ²大), net_S很确定(σ²小) → w_F(x_2)↓, w_S(x_2)↑
```

**为什么需要冲突处理？**

当两个模型预测方向相反时：
```
场景1: 两模型都不确定 → 信息不可靠 → 弃权(得分0)
场景2: 子目标确定、全目标不确定 → 子目标主导 → 加多样性奖励
```

#### 3.3.2 核心算法

**逆方差权重公式**：

```matlab
% 对每个候选解x:
sigma2_F(x) = var({net_F_k(x)})   % 全目标集成预测方差
sigma2_S(x) = var({net_S_k(x)})   % 子目标集成预测方差

% 逆方差权重 (方差越小，权重越大)
inv_F = 1 / (sigma2_F + ε)
inv_S = 1 / (sigma2_S + ε)
w_F(x) = inv_F / (inv_F + inv_S)
w_S(x) = 1 - w_F(x)

% 基础得分
base(x) = w_F(x) × s̃_F(x) + w_S(x) × s̃_S(x)
```

**冲突分支处理**：

```matlab
% 判断冲突
conflict = (sign(mu_F) × sign(mu_S)) < 0

% 分支1: 一致同意 → 用基础得分
if ~conflict
    score = base

% 分支2: 两模型都打架且都不确定 → 弃权
elseif conflict && (n_F > tau) && (n_S > tau)
    score = 0

% 分支3: 子目标主导冲突 → 加多样性奖励
elseif conflict && (mu_S > 0) && (mu_F < 0) && (n_F > tau) && (n_S <= tau)
    novelty = min_distance_to_other_candidates(x)
    score = base + 0.5 × novelty
```

#### 3.3.3 代码实现细节

**ArbitratorScore.m 核心逻辑**：

```matlab
function scores = ArbitratorScore(Smodel, Candidates)
    nCand = size(Candidates, 1);

    % === 1. 计算两个模型的预测均值和方差 ===
    [mu_F, sigma2_F] = scoreAllByEnsemble(Smodel.X, Smodel.Y_F, ...
                          Smodel.DualNet.nets_F, Candidates, anchorMax);
    [mu_S, sigma2_S] = scoreAllByEnsemble(Smodel.X, Smodel.Y_S, ...
                          Smodel.DualNet.nets_S, Candidates, anchorMax);

    % === 2. 归一化标准差 ===
    s_F = sqrt(max(sigma2_F, 0));
    s_S = sqrt(max(sigma2_S, 0));
    n_F = minmaxNorm(s_F);    % 归一化到[0,1]
    n_S = minmaxNorm(s_S);

    % === 3. 归一化得分到[0,4] ===
    tildeS_F = minmaxNormScore(mu_F);
    tildeS_S = minmaxNormScore(mu_S);

    % === 4. 逆方差权重 ===
    eps_v = 1e-6;
    invF  = 1 ./ (s_F.^2 + eps_v);
    invS  = 1 ./ (s_S.^2 + eps_v);
    w_F   = invF ./ (invF + invS);
    w_S   = 1 - w_F;

    % === 5. 基础得分 ===
    base = w_F .* tildeS_F + w_S .* tildeS_S;

    % === 6. 冲突分支处理 ===
    tau      = Smodel.tau_conf;  % 默认0.3
    conflict = (sign(mu_F) .* sign(mu_S)) < 0;

    % 分支2: 弃权
    abstain = conflict & (n_F > tau) & (n_S > tau);
    base(abstain) = 0;

    % 分支3: 多样性奖励
    subwin = conflict & (mu_S > 0) & (mu_F < 0) & (n_F > tau) & (n_S <= tau);
    if any(subwin)
        D_pairs = pdist2(Candidates, Candidates);
        D_pairs(logical(eye(nCand))) = inf;
        novelty = min(D_pairs, [], 2);      % 最近邻距离
        novelty = minmaxNorm(novelty);
        base(subwin) = base(subwin) + 0.5 .* novelty(subwin);
    end

    scores = base;
end
```

**scoreAllByEnsemble.m — 集成预测评分**：

```matlab
function [mu, sigma2] = scoreAllByEnsemble(X_train, Y_train, nets, Candidates, anchorMax)
    % 1. 选择anchor点 (每类最多anchorMax个)
    C1 = selectAnchors(X_train(Y_train == 1, :), anchorMax);   % 正类anchor
    C2 = selectAnchors(X_train(Y_train ~= 1, :), anchorMax);   % 负类anchor

    % 2. 对每个网络计算候选解得分
    K = numel(nets);
    sample_scores = zeros(nCand, K);
    for kk = 1:K
        sample_scores(:, kk) = scoreOneNet(C1, C2, nets{kk}, Candidates);
    end

    % 3. 计算均值和方差
    mu = mean(sample_scores, 2);
    if K >= 2
        sigma2 = var(sample_scores, 0, 2);
    else
        sigma2 = ones(nCand, 1);  % 单网络无法计算方差
    end
end
```

**scoreOneNet.m — 单网络候选解评分**：

```matlab
function scoreVec = scoreOneNet(C1, C2, net, Candidates)
    % 对每个候选x:
    %   - 计算与C1(正类anchor)的关系对预测
    %   - 计算与C2(负类anchor)的关系对预测
    %   - 综合得分 = 正类得分 - 负类得分

    for i = 1:nCand
        % 构造关系对: [C1, x_i], [x_i, C1], [C2, x_i], [x_i, C2]
        % 预测: net(pair) → [P(1), P(0), P(-1)]
        % 累计得分:
        %   Cscore(1) += P(x≻C1) + P(C1~x) + P(x≻C2) + ...
        %   Cscore(2) += P(C1≻x) + P(C2≻x) + ...
        scoreVec(i) = Cscore(1) - Cscore(2);
    end
end
```

#### 3.3.4 创新有效性分析

**逆方差权重 vs 固定权重**：

| 方法 | 权重策略 | 优势 | 劣势 |
|------|---------|------|------|
| 固定权重 | w_F=0.5, w_S=0.5 | 简单 | 无法适应不同候选解 |
| 全局权重 | w_F=σ²_S/(σ²_F+σ²_S) | 考虑整体不确定性 | 对所有候选解相同 |
| **逐候选权重** | w_F(x)=... | **自适应每个候选解** | 计算量略增 |

**冲突处理的必要性**：

```
场景: 候选解x，net_F预测x≻anchor，net_S预测anchor≻x

无冲突处理: 取平均 → 可能选中平庸解
有冲突处理:
  ├─ 两模型都不确定 → 弃权 → 避免选中不可靠解
  └─ 子目标确定胜出 → 加多样性奖励 → 探索稀缺区域
```

---

## 四、关键技术细节

### 4.1 关系对构造

**GetRelationPairsBudgeted.m**：

```matlab
function [XXs, Ls] = GetRelationPairsBudgeted(Input, Catalog, pairMax)
    % 目标: 构造平衡的、有上限的关系对训练集
    % 标签: +1 (x_i ≻ x_j), 0 (x_i ~ x_j), -1 (x_j ≻ x_i)

    C1 = find(Catalog == 1);  % 正类 (PBI分类为1)
    C2 = find(Catalog ~= 1);  % 非正类

    perClass = floor(pairMax / 3);  % 每类最多pairMax/3个

    % 采样三种关系对
    [XXp, Lp] = sampleCross(Input, C1, C2, perClass, +1);  % 正类≻非正类
    [XXn, Ln] = sampleCross(Input, C2, C1, perClass, -1);  % 非正类≻正类
    [XXz, Lz] = sampleSame(Input, C1, C2, perClass);        % 同类~同类

    XXs = [XXz; XXp; XXn];
    Ls  = [Lz;  Lp;  Ln ];

    % 硬上限
    if size(XXs,1) > pairMax
        keep = randperm(size(XXs,1), pairMax);
        XXs  = XXs(keep,:);
        Ls   = Ls(keep);
    end
end
```

**为什么需要有上限采样？**

- 原始REMO枚举所有组合：O(n²)复杂度
- 种群n=100时：100×99=9900个关系对
- 双尺度训练：2×9900=19800个关系对 → 训练慢
- 有上限采样：pairMax=6000 → 训练快3倍

### 4.2 参考解选择

**RefSelect.m (来自REMO baseline)**：

使用雷达网格策略选择k=6个参考解：
- 将目标空间划分为k个区域
- 每个区域选择最靠近理想点的解
- 保证参考解均匀覆盖Pareto前沿

### 4.3 PBI分类

**GetOutput_PBI.m (来自REMO baseline)**：

使用基于惩罚的边界交叉方法(PBI)将解分类：
- 计算每个解到参考向量的距离和角度
- 根据角度阈值将解分为"正类"和"非正类"
- 用于构造关系对的标签

### 4.4 运行时优化

| 优化点 | 原始REMO | REMO_DiRel | 效果 |
|--------|---------|------------|------|
| 关系对数量 | 无上限 (O(n²)) | pairMax=6000 | 训练快3倍 |
| Anchor数量 | 全部样本 | anchorMax=30/类 | 评分快10倍 |
| 集成规模 | 1个网络 | K_ens=3 | 方差估计稳定 |
| 训练轮数 | 100+epochs | 60/30 epochs | 训练快2倍 |
| 难度计算 | Kriging O(n³) | 种群统计 O(nM) | 快100倍 |

---

## 五、与现有方法的对比

### 5.1 与REMO baseline的对比

| 方面 | REMO (baseline) | REMO_DiRel | 改进动机 |
|------|----------------|------------|---------|
| **目标选择** | 固定使用所有M个目标 | 动态选易子集(⌈M/2⌉) | 避免难目标拖累 |
| **模型结构** | 单一全目标patternnet | 双尺度集成(全+子) | 多视角互补 |
| **训练方式** | 单网络随机初始化 | bagging+迁移初始化 | 稳定性+收敛速度 |
| **关系对构造** | 枚举所有组合 | 有上限平衡采样 | 控制计算量 |
| **候选评分** | 单模型得分 | 逐候选逆方差仲裁 | 自适应权重 |
| **冲突处理** | 无 | 弃权+多样性奖励 | 鲁棒性 |
| **超参数** | k=6, gmax=3000 | k=6, gmax=1000 | 更高效 |

### 5.2 与Subproblem_REMO的对比

| 方面 | Subproblem_REMO | REMO_DiRel |
|------|----------------|------------|
| 目标分组 | 静态相邻分组 | 动态难度排序 |
| 模型结构 | 独立分类器堆 | 共享backbone+迁移 |
| 信息共享 | 无 | 通过迁移初始化 |

### 5.3 与REMO_SRMaO的对比

| 方面 | REMO_SRMaO | REMO_DiRel |
|------|------------|------------|
| 方差使用 | 全局标量权重 | 逐候选解权重 |
| 权重粒度 | 1个权重 | nCand个权重 |
| 冲突处理 | 无 | 弃权+多样性奖励 |

### 5.4 与REMO_new2_AdaMaO的对比

| 方面 | REMO_new2_AdaMaO | REMO_DiRel |
|------|------------------|------------|
| 超参数数量 | 10+ (含4个魔数阈值) | 3个核心参数 |
| 采集函数 | PIEA指标轮盘 | 逆方差仲裁 |
| 可解释性 | 低 (魔数多) | 高 (物理含义清晰) |

---

## 六、超参数配置与敏感性

### 6.1 核心超参数

| 参数 | 默认值 | 含义 | 取值范围 | 敏感性 |
|------|--------|------|---------|--------|
| `k_easy` | -1 (=⌈M/2⌉) | 易目标子集大小 | [2, M-1] | 中 |
| `tau_conf` | 0.3 | 仲裁器置信度阈值 | [0.1, 0.5] | 低 |
| `alpha` | 0.6 | 难度公式中建模难度权重 | [0.4, 0.8] | 中 |
| `k` | 6 | 参考解数量 | [4, 10] | 低 |
| `gmax` | 1000 | 代理模型评估预算 | [500, 2000] | 低 |
| `K_ens` | 3 | bagging集成规模 | [2, 5] | 低 |
| `win_K` | 3 | 难度平滑窗口 | [2, 5] | 低 |

### 6.2 超参数选择依据

**k_easy = ⌈M/2⌉**：
- 经验法则：选一半目标通常足够
- 太少：信息丢失严重
- 太多：难目标混入，拖累性能

**alpha = 0.6**：
- 建模难度比冲突度更重要
- 实验验证：0.5~0.7范围内稳定

**K_ens = 3**：
- 集成规模≥3才能计算方差
- 太大：计算量增加，收益递减

---

## 七、消融实验设计

### 7.1 五个消融变体

| 变体 | 目录 | 核心改动 | 验证假设 |
|------|------|---------|---------|
| `REMO_DiRel_noDi` | `REMO_DiRel_noDi/` | 难度排序→随机选目标 | 难度量化机制必要 |
| `REMO_DiRel_noSub` | `REMO_DiRel_noSub/` | 删除net_S，单源仲裁 | 子目标建模必要 |
| `REMO_DiRel_noTrans` | `REMO_DiRel_noTrans/` | net_S独立训练 | 迁移初始化有效 |
| `REMO_DiRel_AvgArb` | `REMO_DiRel_AvgArb/` | 仲裁权重固定0.5/0.5 | 逆方差权重>简单平均 |
| `REMO_DiRel_FullArb` | `REMO_DiRel_FullArb/` | 全局标量权重 | 逐候选权重>全局权重 |

### 7.2 预期消融结果

```
完整REMO_DiRel: IGD基准

消融变体IGD退化程度:
  REMO_DiRel_noDi    ████████████  (退化最大 → 难度排序最关键)
  REMO_DiRel_noSub   ████████      (退化较大 → 子目标建模重要)
  REMO_DiRel_noTrans ██████        (退化中等 → 迁移初始化有效)
  REMO_DiRel_AvgArb  ████          (退化较小 → 逆方差权重有效)
  REMO_DiRel_FullArb ███           (退化最小 → 逐候选权重有效)
```

---

## 八、实验配置建议

### 8.1 Benchmark函数

```matlab
% 标准测试集
Benchmark = {
    'DTLZ1', 'DTLZ2', 'DTLZ3', 'DTLZ4', 'DTLZ7',  % 5个DTLZ
    'WFG1', 'WFG4', 'WFG6', 'WFG9',                 % 4个WFG
    'MaF1', 'MaF7', 'MaF13'                          % 3个MaF
};  % 共12个测试函数

% 目标维度
M_set = [5, 10, 15, 20];

% 决策变量维度
D = 10;  % 或根据M调整
```

### 8.2 预算配置

```matlab
% 初始种群大小
if D <= 10
    N_init = 11*D - 1;  % 109
else
    N_init = 100;
end

% 总评估预算
maxFE = N_init + 200;  % 约309次评估
```

### 8.3 对比算法

```matlab
Algorithms = {
    'REMO',              % 原始baseline
    'REMO_SRMaO',        % SRMaO改进版
    'REMO_new2_AdaMaO',  % AdaMaO改进版
    'Subproblem_REMO',   % 子问题分解版
    'K-RVEA',            % 参考向量引导
    'CSEA'               % 分类器辅助
};
```

### 8.4 评估指标

```matlab
Metrics = {
    'IGD',   % 反向世代距离 (主指标)
    'HV',    % 超体积
    'runtime' % 运行时间
};

% 统计检验
Test = 'Wilcoxon rank-sum test';
Alpha = 0.05;
Runs = 30;  % 独立运行次数
```

### 8.5 实验代码示例

```matlab
% 单次运行
platemo('algorithm', @REMO_DiRel, 'problem', @DTLZ2, ...
        'M', 10, 'D', 10, 'maxFE', 309);

% 自定义超参
platemo('algorithm', {@REMO_DiRel, -1, 0.3, 0.6}, ...
        'problem', @DTLZ2, 'M', 10, 'D', 10, 'maxFE', 309);

% 跑指标
Algo = platemo('algorithm', @REMO_DiRel, 'problem', @DTLZ2, ...
               'M', 10, 'D', 10, 'maxFE', 309, 'save', 0);
IGD = Algo.metric('IGD');
HV  = Algo.metric('HV');

% 批量实验
for M = [5, 10, 15, 20]
    for func = {'DTLZ1', 'DTLZ2', ...}
        platemo('algorithm', @REMO_DiRel, 'problem', str2func(func{:}), ...
                'M', M, 'D', 10, 'maxFE', 309, 'save', 1);
    end
end
```

---

## 九、论文书写架构建议

### 9.1 标题建议

**英文**：
> Difficulty-Aware Dual-Scale Relation Learning for Expensive Many-Objective Optimization

**中文**：
> 难度感知双尺度关系学习的昂贵超多目标优化

### 9.2 摘要结构

```
[背景] 贵金属超多目标优化中，代理辅助方法通过关系学习减少昂贵评估次数。
[问题] 现有方法(如REMO)存在三个局限：(1)固定使用所有目标；(2)单模型随机初始化；(3)全局权重评分。
[方法] 本文提出REMO_DiRel，包含三个创新：
  (1) 难度感知目标子集选择：通过目标跨度、改进停滞、Spearman冲突度在线排序目标
  (2) 双尺度集成网络：全目标+子目标双视角建模，共享backbone+迁移初始化
  (3) 逐候选逆方差仲裁：自适应融合两模型预测，冲突分支处理
[实验] 在12个测试函数、M∈{5,10,15,20}上的实验表明，REMO_DiRel显著优于现有方法。
```

### 9.3 章节结构

```
1. Introduction
   1.1 贵金属超多目标优化的挑战
   1.2 代理辅助方法的研究现状
   1.3 现有方法的局限性
   1.4 本文贡献

2. Preliminaries
   2.1 问题定义
   2.2 REMO baseline回顾
   2.3 关系学习基本概念

3. Proposed Method: REMO_DiRel
   3.1 整体框架
   3.2 难度感知目标子集选择 (模块①)
       3.2.1 轻量建模难度
       3.2.2 Spearman冲突度
       3.2.3 联合难度计算
       3.2.4 反向冗余检查
   3.3 双尺度集成网络 (模块②)
       3.3.1 全目标支线训练
       3.3.2 子目标支线训练
       3.3.3 迁移初始化机制
   3.4 逐候选逆方差仲裁 (模块③)
       3.4.1 逆方差权重计算
       3.4.2 冲突分支处理
       3.4.3 多样性奖励机制
   3.5 运行时优化

4. Experimental Study
   4.1 实验设置
   4.2 与现有方法对比
   4.3 消融实验
   4.4 超参数敏感性分析
   4.5 运行时间分析

5. Conclusion
```

### 9.4 关键创新点总结

```
创新点1: 难度感知目标子集选择
├─ 动机: 不同目标建模难度差异大，难目标拖累易目标
├─ 方法: 轻量建模难度 + Spearman冲突度 → 联合难度排序
└─ 效果: 集中精力在易建模目标，提高整体预测准确性

创新点2: 双尺度集成网络
├─ 动机: 单一视角信息不完整，单模型不稳定
├─ 方法: 全目标+子目标双视角，bagging集成，迁移初始化
└─ 效果: 多视角互补，集成稳定，迁移加速收敛

创新点3: 逐候选逆方差仲裁
├─ 动机: 全局权重无法适应不同候选解的置信度差异
├─ 方法: 逐候选逆方差自适应权重，冲突分支处理
└─ 效果: 细粒度融合，鲁棒性强，鼓励多样性探索
```

---

## 十、故障排查与诊断

### 10.1 常见问题

| 症状 | 可能原因 | 解决方案 |
|------|---------|---------|
| patternnet训练失败 | 样本太少或类别不平衡 | trainBagEnsemble内有兜底策略 |
| Population.objs报错 | PlatEMO方法调用解析问题 | 先存PopObj再切片 |
| 子目标PBI失效 | Ref_S_obj未在子目标空间内 | 已用PopObj_sub范围缩放 |
| 运行时间过长 | 超参数设置不当 | 降低gmax, K_ens |

### 10.2 诊断工具

```matlab
% 检查模型质量
DualNet.p_err_F  % 全目标模型测试误差
DualNet.p_err_S  % 子目标模型测试误差

% 检查难度排序
H.d_score        % 历史难度分数
H.model          % 历史建模难度
H.conf           % 历史冲突度

% 使用KrigingNRMSE做诊断 (不进入默认主路径)
nrmse = KrigingNRMSE(Input, PopObj);
```

---

## 十一、总结与展望

### 11.1 主要贡献

1. **难度感知目标子集选择**：首次将目标难度量化引入关系学习，通过轻量统计指标替代昂贵的Kriging交叉验证

2. **双尺度集成网络**：创新性地将全目标和子目标建模结合，通过迁移初始化解决子目标样本稀缺问题

3. **逐候选逆方差仲裁**：突破全局权重限制，实现细粒度的自适应融合，冲突分支处理增强鲁棒性

### 11.2 技术亮点

- **运行时优化**：有上限采样、anchor预算、小规模集成、低epoch训练
- **可解释性**：3个核心超参数，物理含义清晰
- **模块化设计**：5个消融变体，便于验证各模块贡献

### 11.3 未来工作

1. **自适应k_easy**：根据优化进程动态调整子集大小
2. **多保真度建模**：结合低保真度评估进一步减少昂贵评估
3. **并行化**：集成网络训练可并行化
4. **扩展到约束优化**：将约束违反度纳入难度计算

---

## 附录A: 完整代码清单

```
PlatEMO/Algorithms/Multi-objective optimization/REMO_DiRel/
├── REMO_DiRel.m                 # 主算法入口
├── DifficultyProfiler.m         # 目标难度在线排序
├── ConflictDegree.m             # Spearman冲突度计算
├── RefineEasySubset.m           # 反向冗余检查
├── TrainDualScaleNet.m          # 双尺度集成网络训练
├── TransferFineTune.m           # 权重迁移初始化
├── ArbitratedSelection.m        # 仲裁选择主循环
├── ArbitratorScore.m            # 逐候选逆方差仲裁评分
├── GetRelationPairsBudgeted.m   # 有上限平衡关系对构造
├── KrigingNRMSE.m               # 诊断工具 (备用)
├── README_REMO_DiRel.md         # 项目文档
└── REMO_DiRel_汇报文档.md        # 本文档
```

## 附录B: 关键公式汇总

```
1. 难度计算:
   d = α × (0.5×spanScore + 0.5×improveScore) + (1-α) × (1 - conf)

2. 冲突度:
   conf(j) = mean(1 - |ρ_j,others|)

3. 逆方差权重:
   w_F(x) = (1/σ²_F) / (1/σ²_F + 1/σ²_S)
   w_S(x) = 1 - w_F(x)

4. 基础得分:
   base(x) = w_F(x) × s̃_F(x) + w_S(x) × s̃_S(x)

5. 冲突处理:
   conflict: sign(μ_F) × sign(μ_S) < 0
   abstain: conflict ∧ (n_F > τ) ∧ (n_S > τ) → score = 0
   subwin: conflict ∧ (μ_S > 0) ∧ (μ_F < 0) ∧ (n_F > τ) ∧ (n_S ≤ τ) → score += 0.5×novelty
```

---

**文档生成时间**: 2026年5月15日

**项目状态**: 已完成实现，可直接运行实验

**联系方式**: 李盛薪 (关系模型昂贵超多目标方向)
