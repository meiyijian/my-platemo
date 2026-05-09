# DISK 算法详解

> **DISK** (Distribution Information based Kriging-assisted evolutionary algorithm)
> 基于分布信息的克里金辅助进化算法

## 目录

- [1. 算法简介](#1-算法简介)
- [2. 算法背景与动机](#2-算法背景与动机)
- [3. 整体框架](#3-整体框架)
- [4. 核心模块详解](#4-核心模块详解)
  - [4.1 主算法流程 (DISK.m)](#41-主算法流程-diskm)
  - [4.2 克里金代理模型 (dacefit.m / predictor.m)](#42-克里金代理模型-dacefitm--predictorm)
  - [4.3 基于分布信息的非支配排序 (NDSort_DIPD.m)](#43-基于分布信息的非支配排序-ndsort_dipdm)
  - [4.4 候选解选择 (NewSelect.m)](#44-候选解选择-newselectm)
  - [4.5 自适应探索机制 (IdentifyW.m + LocalSearch.m)](#45-自适应探索机制-identifywm--localsearchm)
  - [4.6 环境选择 (EnvironmentalSelection.m / SEnvironmentalSelection.m)](#46-环境选择-environmentalselectionm--senvironmentalselectionm)
  - [4.7 进化算子 (DE 算子)](#47-进化算子-de-算子)
- [5. 算法关键创新点](#5-算法关键创新点)
- [6. 算法参数说明](#6-算法参数说明)
- [7. 算法伪代码](#7-算法伪代码)
- [8. 适用场景](#8-适用场景)
- [9. 参考文献](#9-参考文献)

---

## 1. 算法简介

**DISK** 是一种针对**昂贵多目标/超多目标优化问题**（Expensive Many-objective Optimization Problems, EMaOPs）的代理模型辅助进化算法，由 Z. Zhang 等人于 2024 年发表在 *IEEE Transactions on Evolutionary Computation* 上。

| 特性 | 说明 |
|------|------|
| **分类** | 多目标 / 超多目标 |
| **变量类型** | 实数 / 整数 |
| **应用场景** | 昂贵优化（expensive optimization） |
| **代理模型** | Kriging（克里金模型） |
| **核心机制** | 分布信息引导 + 概率支配 + 自适应探索 |

### 主要特色

1. **代理模型加速**：使用 Kriging 模型近似昂贵的目标函数评估，大幅减少真实评估次数。
2. **分布信息引导**：通过学习当前种群的多元高斯分布，引导搜索方向。
3. **概率支配关系**：考虑代理模型预测的不确定性，使用概率支配代替严格支配。
4. **自适应探索-开发平衡**：根据候选解质量动态决定是否进行局部搜索。

---

## 2. 算法背景与动机

### 昂贵优化的挑战

在工程优化领域（如气动设计、结构优化等），单次目标函数评估可能需要数小时甚至数天的仿真计算。传统进化算法需要数万次评估才能收敛，对昂贵问题完全不可行。

### 现有方法的局限

- **传统 SAEA（代理辅助进化算法）**：常忽略种群分布特征，可能丢失全局结构信息。
- **多目标场景下的不确定性**：代理模型预测存在误差，简单使用预测值容易误导搜索。
- **超多目标（M ≥ 4）困境**：高维目标空间中，传统支配关系区分能力下降。

### DISK 的设计思路

DISK 通过以下三个核心机制应对上述挑战：

```
昂贵评估 → Kriging 代理模型替代
不确定性 → 概率支配 (Probabilistic Dominance)
分布信息 → 多元高斯密度加权
```

---

## 3. 整体框架

DISK 算法的整体流程可以分为 **5 个核心阶段**：

```
┌────────────────────────────────────────────────────┐
│  ① 初始化：Latin 超立方采样 + 真实评估              │
└────────────────────────────────────────────────────┘
                         ↓
┌────────────────────────────────────────────────────┐
│  ② 构建/更新 Kriging 代理模型 (model_train)         │
└────────────────────────────────────────────────────┘
                         ↓
┌────────────────────────────────────────────────────┐
│  ③ 学习分布信息：均值 μ、协方差 K                   │
└────────────────────────────────────────────────────┘
                         ↓
┌────────────────────────────────────────────────────┐
│  ④ 代理模型辅助进化搜索 (optimizaiton + GA)         │
└────────────────────────────────────────────────────┘
                         ↓
┌────────────────────────────────────────────────────┐
│  ⑤ 候选解选择 (NewSelect, 基于 DIPD)               │
└────────────────────────────────────────────────────┘
                         ↓
┌────────────────────────────────────────────────────┐
│  ⑥ 自适应探索：判断是否需要局部搜索                 │
│     若是 → IdentifyW + LocalSearch                 │
└────────────────────────────────────────────────────┘
                         ↓
┌────────────────────────────────────────────────────┐
│  ⑦ 种群更新 (EnvironmentalSelection)                │
└────────────────────────────────────────────────────┘
                         ↓
                   未达到终止条件 → 回到 ②
```

---

## 4. 核心模块详解

### 4.1 主算法流程 (DISK.m)

主算法的关键代码逻辑：

```matlab
%% 初始化
NI    = Problem.N;                              % 种群规模
OP    = UniformPoint(NI,Problem.D,'Latin');     % Latin 超立方采样
A2    = Problem.Evaluation(...);                % 真实评估初始种群
A1    = A2;                                     % 辅助种群
THETA = 5.*ones(Problem.M,Problem.D);           % Kriging 超参数初值
Model = cell(1,Problem.M);                      % M 个 Kriging 模型

while Algorithm.NotTerminated(A2)
    [Model,THETA] = model_train(A2,Model,THETA);   % 训练代理模型
    
    % 学习分布
    [F,~]  = NDSort(A2.objs,inf);
    PopDec = A2(F==1).decs;
    if size(PopDec,1) <= 1
        PopDec = [PopDec; A2(F==2).decs];
    end
    mu = mean(PopDec,1);                          % 均值向量
    K  = (PopDec-mu)'*(PopDec-mu)/(size(PopDec,1)-1);  % 协方差矩阵

    OP = optimizaiton(A1,wmax,Model,Problem);     % 代理辅助搜索
    C  = NewSelect(OP,A2,alpha,Problem);          % 候选解选择
    
    % 自适应探索
    flag = 0;
    if ~isempty(C)
        flag = judgeLS(C,A2);
        A2   = [A2,C];
    end
    if flag == 1
        [Model,THETA] = model_train(A2,Model,THETA);
        [W,ideal]     = IdentifyW(A2,Problem.N,Problem.M);
        A2            = LocalSearch(OP,W,ideal,wmax,Model,A2,Problem);
    end

    index = EnvironmentalSelection(A2.objs,NI);
    A1    = A2(index);
end
```

#### 关键变量

| 变量 | 含义 |
|------|------|
| `A2` | 真实评估的解集（数据库） |
| `A1` | 辅助种群（用于代理辅助搜索） |
| `Model` | 每个目标的 Kriging 模型集合 |
| `THETA` | Kriging 模型超参数 |
| `mu`, `K` | 第一前沿解集在决策空间的均值和协方差（全局变量） |
| `OP` | 代理辅助进化产生的候选种群 |
| `C` | 经过 DIPD 选择并真实评估的新候选解 |

#### `judgeLS` 局部搜索触发条件

```matlab
function flag = judgeLS(C,A2)
    [F1,~] = NDSort(C.objs,1);
    AObj   = C(F1==1).objs;          % 候选解的非支配集
    [F2,~] = NDSort(A2.objs,1);
    A2Obj  = A2(F2==1).objs;         % 数据库的非支配集
    
    % 判断 C 中是否有解能支配 A2 中的非支配解
    dominate = zeros(N1,N2);
    for i = 1:N1, for j = 1:N2
        if all(AObj(i,:)<=A2Obj(j,:)) && ~all(AObj(i,:)==A2Obj(j,:))
            dominate(i,j) = true;
        end
    end, end
    
    if any(any(dominate))
        flag = 0;     % 候选解有进展，不需局部搜索
    else
        flag = 1;     % 候选解无进展，需要局部搜索探索
    end
end
```

> **核心逻辑**：如果新选出的候选解能"推进" Pareto 前沿，则继续正常进化；否则说明搜索停滞，需要进行**有方向引导的局部搜索**来探索新区域。

---

### 4.2 克里金代理模型 (dacefit.m / predictor.m)

DISK 使用 **DACE 工具箱**实现 Kriging 模型。

#### 模型形式

Kriging 模型假设响应函数为：

$$
y(x) = f(x)^T \beta + z(x)
$$

其中：
- $f(x)^T \beta$：回归项（DISK 使用一阶多项式 `regpoly1`）
- $z(x)$：均值为 0 的高斯随机过程，相关函数使用**高斯核** `corrgauss`

#### 高斯相关函数

$$
R(x_i, x_j) = \prod_{k=1}^{D} \exp\left(-\theta_k (x_{i,k} - x_{j,k})^2\right)
$$

代码实现：

```matlab
function [r,dr] = corrgauss(theta,d)
    td = d.^2 .* repmat(-theta(:).',m,1);
    r  = exp(sum(td, 2));
    dr = repmat(-2*theta(:).',m,1) .* d .* repmat(r,1,n);
end
```

#### 模型训练

```matlab
dmodel = dacefit(Dec(distinct,:), Obj(distinct,i), ...
                 'regpoly1', 'corrgauss', ...
                 THETA(i,:), 1e-5*ones(1,Len_dec), 100*ones(1,Len_dec));
```

`dacefit` 通过约束的 box-min 算法，在 $\theta \in [10^{-5}, 100]^D$ 范围内极大化对数似然函数，求解最优超参数。

#### 模型预测

```matlab
[OffObj(i,j), ~, Off_ObjMSE(i,j)] = predictor(OffDec(i,:), Model{j});
```

返回：
- **预测值** $\hat{y}(x)$
- **均方误差（MSE）** $s^2(x)$，反映预测不确定性

#### 重复样本去重

```matlab
[~,distinct1] = unique(round(Dec*1e100)/1e100,'rows');
[~,distinct2] = unique(round(Obj(:,i)*1e100)/1e100,'rows');
distinct      = intersect(distinct1,distinct2);
```

避免相同样本导致 Kriging 相关矩阵奇异。

---

### 4.3 基于分布信息的非支配排序 (NDSort_DIPD.m)

**DIPD = Distribution Information based Probabilistic Dominance**（分布信息概率支配）

这是 DISK 算法**最核心的创新**。

#### Step 1：计算每个解的分布概率密度

利用第一前沿解集的均值 μ 和协方差 K，计算每个候选解 $x_j$ 的多元高斯密度：

$$
P(x_j) = \frac{1}{\sqrt{|K|} \cdot (2\pi)^{D/2}} \exp\left(-\frac{1}{2}(x_j - \mu)^T K^{-1} (x_j - \mu)\right)
$$

```matlab
Pro(j,:) = (1/(det(K)^(1/2)*(2*pi)^(D/2))) * ...
           exp(-0.5*(PopDec(j,:) - mu)*(K^-1)*(PopDec(j,:) - mu)');
```

> **物理意义**：$P(x_j)$ 衡量候选解 $x_j$ 在当前精英分布下的"可能性"，靠近精英解集中心的解具有较高的密度。

#### Step 2：计算概率支配关系

考虑代理模型预测不确定性，对每对解 $(i, j)$：

- 预测值差异：$\mu_{ij} = \hat{y}(x_i) - \hat{y}(x_j)$
- 标准差合成：$\sigma_{ij} = \sqrt{s^2(x_i) + s^2(x_j)}$

$x_i$ 在某目标上**优于** $x_j$ 的概率：

$$
P(x_i \prec x_j) = \Phi\left(\frac{0 - \mu_{ij}}{\sigma_{ij}}\right)
$$

```matlab
sigma = sqrt(ObjMSE(reshape(ones(N,1)*(1:N),N*N,1),:) + repmat(ObjMSE,N,1));
mean  = PopObj(reshape(ones(N,1)*(1:N),N*N,1),:) - repmat(PopObj,N,1);
x_PD  = normcdf((0-mean)./sigma);   % i 优于 j 的概率
y_PD  = 1 - x_PD;                    % j 优于 i 的概率
```

#### Step 3：用分布信息加权概率支配

$$
PD'(x_i \prec x_j) = -P(x_i \prec x_j) \cdot P(x_i)
$$

$$
PD'(x_j \prec x_i) = -(1 - P(x_i \prec x_j)) \cdot P(x_j)
$$

```matlab
x_PD = - x_PD .* Pro(reshape(ones(N,1)*(1:N),N*N,1),:);
y_PD = - y_PD .* repmat(Pro,N,1);
```

> **核心思想**：将"统计支配优势"与"分布密度优势"相乘，使位于精英分布中心的解在支配比较中获得更高权重。

#### Step 4：判定支配关系并排序

如果在所有目标上都满足 $PD'(x_i \prec x_j) \le PD'(x_j \prec x_i)$ 且至少一个严格小于，则判定 $x_i$ 概率支配 $x_j$。

```matlab
for i = 1:N-1, for j = i+1:N
    if all(x_PD(...) <= y_PD(...)) && ~all(x_PD(...) == y_PD(...))
        dominate(i,j) = true;
    elseif all(x_PD(...) >= y_PD(...)) && ~all(x_PD(...) == y_PD(...))
        dominate(j,i) = true;
    end
end, end
```

最后通过迭代剥离最少被支配的解，得到层次化前沿编号 `FrontNo`。

---

### 4.4 候选解选择 (NewSelect.m)

从代理辅助进化产生的大量候选解中选择 `alpha` 个进行真实评估。

#### 选择流程

**Step 1：去除已评估的解**

```matlab
for i = 1:size(P.decs,1)
    dist2 = pdist2(real(P.decs(i,:)),real(DB.decs));
    if min(dist2) > 1e-50, index = [index,i]; end
end
```

**Step 2：归一化**

```matlab
zmin = min([A2Obj;PopObj],[],1); zmax = max([A2Obj;PopObj],[],1);
A2Obj  = (A2Obj - zmin)./max(zmax - zmin,10e-10);
PopObj = (PopObj - zmin)./max(zmax - zmin,10e-10);
ObjMSE = ObjMSE./(max(zmax - zmin,10e-10).^2);
```

**Step 3：DIPD 排序保留第一前沿**

```matlab
[FrontNo,~] = NDSort_DIPD(PopDec,PopObj,ObjMSE,1);
PopDec = PopDec(FrontNo==1,:);
```

**Step 4：基于角度距离的迭代选择**

迭代 `alpha` 次，每次选择**距当前 Pareto 前沿角度距离最远**的解：

```matlab
while length(find(Pindex==0)) < alpha
    Last     = find(Pindex==1);
    Dis      = Distance(PopObj(Last,:),A2Obj);    % 角度距离
    [~,Rank] = sort(Dis,'descend');
    PopNew   = PopDec(Last(Rank(1)),:);
    C        = [C,Problem.Evaluation(PopNew)];     % 真实评估
    
    % 更新前沿后再选择，保证多样性
    A2Obj = [DB.objs;C.objs];
    [F_P,~] = NDSort(A2Obj,1);
    A2Obj = unique(A2Obj(F_P==1,:),'rows');
    A2Obj = (A2Obj - zmin)./max(zmax - zmin,10e-10);
    
    Pindex(Last(Rank(1))) = 0;
end
```

#### 角度距离计算

```matlab
function dis = Distance(PopObj,OffObj)
    dis = acos(1-pdist2(PopObj,OffObj,'cosine'));   % 余弦角度
    dis = sort(dis,2);
    dis = dis(:,1);   % 取最小角度（与最近的前沿解的距离）
end
```

> **设计意图**：每次选择能够**填补当前前沿空白**的候选解，提升 Pareto 前沿的覆盖度和多样性。

---

### 4.5 自适应探索机制 (IdentifyW.m + LocalSearch.m)

当 `judgeLS` 检测到搜索停滞时，触发**有方向引导的局部搜索**。

#### IdentifyW：识别最稀疏方向

**步骤**：
1. 生成 `10*N` 个均匀分布的权重向量 V
2. 平移目标空间到调整后的理想点为原点
3. 计算每个权重向量与第一前沿解的最小角度
4. 选择**最小角度最大**的权重向量（即最远离当前前沿的方向）

```matlab
V      = UniformPoint(10*N,M);
[F_,~] = NDSort(A2Obj,1);
A2Obj  = A2Obj(F_==1,:);

nadir = max(A2Obj,[],1);
ideal = min(A2Obj,[],1);
ideal = ideal - (nadir-ideal)/10 - 0.1*ones(1,M);   % 适当外推理想点
A2Obj = A2Obj - ideal;

Angle  = acos(1-pdist2(V,A2Obj,'cosine'));
Angle_ = sort(Angle,2);
index  = find(Angle_(:,1)==max(Angle_(:,1)));      % 最稀疏方向
```

#### LocalSearch：方向引导的局部搜索

**Step 1：组合多种变异算子产生候选**

```matlab
OffDec1 = OperatorGA(Problem,P.decs);                      % 模拟二进制交叉+多项式变异
OffDec2 = OperatorDE_current_rand_1(Problem,P.decs);       % DE/current-to-rand/1
OffDec3 = OperatorDE_rand_1(Problem,P.decs);               % DE/rand/1
OffDec4 = OperatorDE_current_rand_1(Problem,P.decs);
P.decs  = unique([P.decs;OffDec1;OffDec2;OffDec3;OffDec4],'rows');
```

**Step 2：基于加权切比雪夫的适应度**

$$
\text{fitness}(x) = \max_{i=1,\dots,M} W_i \cdot |\hat{y}_i(x) - z_i^*| - 2 \cdot \overline{s(x)}
$$

```matlab
fitness = max(abs(P.objs - ideal).*W,[],2) - 2*mean(P.objmse,2);
```

> **设计意图**：
> - 第一项 $\max W_i|\hat{y}_i - z_i^*|$：沿最稀疏方向 W 的加权切比雪夫距离，越小越好
> - 第二项 $-2 \cdot \overline{s(x)}$：奖励高不确定性区域，鼓励探索

**Step 3：选择 fitness 最小的解进行真实评估**

```matlab
[~,Rank] = sort(fitness);
PopNew   = P.decs(Rank(1),:);
dist2    = pdist2(real(PopNew),real(DB.decs));
if min(dist2) > 1e-50
    DB = [DB,Problem.Evaluation(PopNew)];
end
```

---

### 4.6 环境选择 (EnvironmentalSelection.m / SEnvironmentalSelection.m)

DISK 中有两类环境选择：

#### 4.6.1 真实环境选择 (EnvironmentalSelection.m)

用于真实评估种群的精英保留。

```matlab
% 1. 归一化
zmin = min(PopObj); zmax = max(PopObj);
PopObj = (PopObj - zmin)./max(zmax - zmin,10e-10);

% 2. 经典非支配排序
[FrontNo,MaxFNo] = NDSort(PopObj,N);
Next = FrontNo < MaxFNo;
Last = find(FrontNo == MaxFNo);

% 3. 处理临界前沿
if MaxFNo == 1
    Del = Truncation(PopObj(Last,:),N);
    Next(Last(Del)) = true;
else
    Choose = Dist_Selection(PopObj(Next,:),PopObj(Last,:),N - sum(Next));
    Next(Last(Choose)) = true;
end
```

##### `Dist_Selection`（基于分布的选择）

迭代选择"距已选解集角度距离最大"的解：

```matlab
Distance = acos(1-pdist2(PopObj,PopObj,'cosine'));
for i = 1:mu
    Distance1 = sort(Distance(Next2,Next1),2);
    [~,index] = max(Distance1(:,1));
    Next1 = [Next1,Next2(index)];
end
```

##### `Truncation`（截断选择）

迭代删除"最拥挤"（与其他解角度距离最近）的解：

```matlab
while sum(Del) > K
    Remain   = find(Del);
    Temp     = sort(Distance(Remain,Remain),2);
    [~,Rank] = sortrows(Temp);
    Del(Remain(Rank(1))) = false;
end
```

#### 4.6.2 代理环境选择 (SEnvironmentalSelection.m)

用于代理辅助进化中的种群更新，**关键区别**：使用 `NDSort_DIPD` 而非 `NDSort`。

```matlab
[FrontNo,MaxFNo] = NDSort_DIPD(PopDec,PopObj,PopMSE,N);
```

> 在代理空间中，预测不确定性不可忽略，因此采用考虑 MSE 与分布的概率支配进行排序。

---

### 4.7 进化算子 (DE 算子)

DISK 在局部搜索中使用了两种 DE 变异策略，并融合多项式变异。

#### DE/rand/1（探索性更强）

$$
v_i = x_{p_1} + F \cdot (x_{p_2} - x_{p_3})
$$

```matlab
Offspring(Site) = Parent1(Site) + F(Site).*(Parent2(Site)-Parent3(Site));
```

#### DE/current-to-rand/1（保留当前信息）

$$
v_i = x_i + F \cdot (x_{p_1} - x_i) + F \cdot (x_{p_2} - x_{p_3})
$$

```matlab
Offspring(Site) = Parent(Site) + F(Site).*(Parent1(Site)-Parent(Site)) ...
                              + F(Site).*(Parent2(Site)-Parent3(Site));
```

#### 自适应参数集合

```matlab
Fm  = [0.6, 0.8, 1.0];   % 缩放因子
CRm = [0.1, 0.2, 1.0];   % 交叉概率
```

每个个体随机选取一组 (F, CR)，提升参数鲁棒性。

#### 多项式变异（PM）

变异分布指数 `disM = 20`，每个变量的变异概率为 `1/D`：

```matlab
% mu <= 0.5
Offspring(temp) = Offspring(temp) + (Upper-Lower).*...
    ((2*mu+(1-2*mu).*(1-(Offspring-Lower)./(Upper-Lower)).^(disM+1)).^(1/(disM+1))-1);

% mu > 0.5  
Offspring(temp) = Offspring(temp) + (Upper-Lower).*...
    (1-(2*(1-mu)+2*(mu-0.5).*(1-(Upper-Offspring)./(Upper-Lower)).^(disM+1)).^(1/(disM+1)));
```

---

## 5. 算法关键创新点

### 5.1 概率支配 + 分布加权（核心贡献）

| 传统方法 | DISK 的 DIPD |
|---------|-------------|
| 严格支配比较 | 概率支配（考虑 MSE） |
| 各解地位均等 | 分布密度加权 |
| 易受预测误差误导 | 鲁棒性更强 |

### 5.2 自适应探索-开发切换

```
candidate dominates Pareto front?
    YES → 当前进化方向有效，继续
    NO  → 进入有方向引导的局部搜索
            ↓
            IdentifyW 找最稀疏方向
            LocalSearch 沿该方向 + 不确定性奖励
```

### 5.3 角度距离的多样性维护

DISK 在多个模块（候选选择、环境选择、最远方向识别）中统一使用**角度距离**：

$$
d_{\text{angle}}(x_i, x_j) = \arccos\left(1 - \frac{x_i \cdot x_j}{\|x_i\| \cdot \|x_j\|}\right)
$$

相比欧氏距离，角度距离在超多目标问题中更能反映 Pareto 前沿的几何分布特性。

### 5.4 多算子协同

局部搜索同时使用 GA + DE/rand/1 + DE/current-to-rand/1，利用它们不同的搜索特性：
- **GA（SBX+PM）**：利用 + 局部精修
- **DE/rand/1**：纯探索
- **DE/current-to-rand/1**：兼顾当前解与多样性

---

## 6. 算法参数说明

| 参数 | 默认值 | 含义 | 影响 |
|------|--------|------|------|
| `wmax` | 60 | 代理辅助进化代数 / 局部搜索代数 | 越大代理上的搜索越充分，但耗时增加 |
| `alpha` | 5 | 每代选择的真实评估候选解数量 | 越大每代真实评估开销越高 |
| `NI` | `Problem.N` | 初始种群规模 | Latin 超立方采样数量 |
| `THETA` | 5 | Kriging 超参数初值 | 影响 Kriging 拟合速度 |
| `Fm` | [0.6,0.8,1.0] | DE 缩放因子集合 | 控制差分扰动幅度 |
| `CRm` | [0.1,0.2,1.0] | DE 交叉概率集合 | 控制交叉规模 |
| `disM` | 20 | 多项式变异分布指数 | 越大变异越集中 |

---

## 7. 算法伪代码

```
算法: DISK
输入: 问题 Problem, 进化代数 wmax, 候选数 alpha
输出: 真实评估的非支配解集

1.  NI ← Problem.N
2.  OP ← LatinHypercube(NI, D)                     // 初始采样
3.  A2 ← Problem.Evaluation(OP)                    // 真实评估
4.  A1 ← A2
5.  Model ← {} (M 个空 Kriging 模型)

6.  while 未达终止条件 do
7.      Model ← TrainKriging(A2)                   // 更新代理模型
        
8.      F1 ← NDSort(A2)                            // 学习分布
9.      μ ← mean(A2[F1==1].decs)
10.     K ← cov(A2[F1==1].decs)
        
11.     OP ← OptimizeWithSurrogate(A1, wmax, Model)  // 代理辅助进化
12.     C  ← NewSelect(OP, A2, alpha)              // DIPD 选择并真实评估
        
13.     flag ← 0
14.     if C ≠ ∅ then
15.         flag ← JudgeLS(C, A2)                  // 判断是否需要局部搜索
16.         A2 ← A2 ∪ C
17.     end if
        
18.     if flag == 1 then
19.         Model ← TrainKriging(A2)
20.         (W, ideal) ← IdentifyW(A2)             // 找最稀疏方向
21.         A2 ← LocalSearch(OP, W, ideal, wmax, Model, A2)
22.     end if
        
23.     index ← EnvironmentalSelection(A2.objs, NI)
24.     A1 ← A2[index]
25. end while

26. return A2
```

---

## 8. 适用场景

### 推荐应用

- **昂贵评估问题**：仿真耗时长（如 CFD、FEA），评估次数严格受限（通常 < 1000 次）
- **超多目标问题**：M ≥ 4，传统 Pareto 支配区分度下降
- **连续/混合变量**：实数或可松弛为实数的整数变量
- **中等维度决策空间**：D 在几十量级（Kriging 在高维下计算复杂度高）

### 不推荐场景

- **高维决策变量**（D > 100）：Kriging 训练 O(N³)，且高维下相关函数衰减剧烈
- **离散组合优化**：Kriging 需连续核函数
- **极端噪声目标**：DISK 假设确定性目标函数（虽用 MSE 处理近似不确定性）

---

## 9. 参考文献

> Z. Zhang, Y. Wang, G. Sun, and T. Pang.
> **A distribution information based Kriging-assisted evolutionary algorithm for expensive many-objective optimization problems.**
> *IEEE Transactions on Evolutionary Computation*, 2024.

PlatEMO 平台引用：

> Y. Tian, R. Cheng, X. Zhang, Y. Jin.
> **PlatEMO: A MATLAB platform for evolutionary multi-objective optimization.**
> *IEEE Computational Intelligence Magazine*, 2017, 12(4): 73-87.

DACE 工具箱（Kriging 实现）：

> H. B. Nielsen, S. N. Lophaven, J. Søndergaard.
> **DACE: A MATLAB Kriging Toolbox.** Technical University of Denmark, 2002.

---

## 附录：代码文件结构

```
DISK/
├── DISK.m                          # 主算法入口
├── EnvironmentalSelection.m        # 真实环境选择
├── SEnvironmentalSelection.m       # 代理空间环境选择
├── NDSort_DIPD.m                   # 基于分布信息的概率支配排序（核心）
├── NewSelect.m                     # 候选解选择
├── IdentifyW.m                     # 识别最稀疏权重方向
├── LocalSearch.m                   # 方向引导的局部搜索
├── OperatorDE_rand_1.m             # DE/rand/1 算子
├── OperatorDE_current_rand_1.m     # DE/current-to-rand/1 算子
├── dacefit.m                       # Kriging 模型训练（DACE）
└── predictor.m                     # Kriging 模型预测（DACE）
```

### 模块调用关系

```
DISK.m (主流程)
  ├── model_train ──→ dacefit.m
  ├── optimizaiton
  │     ├── OperatorGA (PlatEMO 内置)
  │     ├── model_predict ──→ predictor.m
  │     └── SEnvironmentalSelection ──→ NDSort_DIPD
  ├── NewSelect ──→ NDSort_DIPD
  ├── judgeLS
  ├── IdentifyW
  ├── LocalSearch
  │     ├── OperatorGA
  │     ├── OperatorDE_current_rand_1
  │     ├── OperatorDE_rand_1
  │     └── model_predict ──→ predictor.m
  └── EnvironmentalSelection
```

---

*文档生成于 2026-05-04，针对 PlatEMO 框架下的 DISK 算法实现。*
