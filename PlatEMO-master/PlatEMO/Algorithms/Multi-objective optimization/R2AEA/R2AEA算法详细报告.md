# R2AEA 算法详细报告

## 一、算法概述

### 1.1 算法全称
**R2AEA: Regression and Relation-Assisted Evolutionary Algorithm**
（回归与关系辅助的进化算法）

### 1.2 论文信息
- **标题**: Regression and relation-assisted evolutionary algorithm for high-dimensional expensive multi-objective optimization
- **作者**: Zhu S, Zhang Y, Fang W, et al.
- **期刊**: Swarm and Evolutionary Computation
- **年份**: 2025
- **卷号**: 97: 101978

### 1.3 算法定位
- **问题类型**: 多目标优化（Multi-objective Optimization）
- **变量类型**: 实数/整数（Real/Integer）
- **目标规模**: 大规模目标（Large-scale Objectives）
- **应用场景**: **高维昂贵多目标优化**（High-dimensional Expensive Multi-objective Optimization）

### 1.4 核心创新点
1. **两阶段协作设计**：回归辅助的径向权重优化（RWO）+ 关系辅助的进化优化（RMO）
2. **关系模型替代回归模型**：在高维目标空间中学习解对优劣关系，比直接回归更稳健
3. **不确定性感知选择**：同时考虑预测性能和不确定性，降低代理模型误判风险
4. **PBI自适应分类**：通过二分搜索自适应调整惩罚参数，确保分类标签平衡

---

## 二、文件结构与功能

### 2.1 文件清单

| 文件名 | 大小 | 功能描述 |
|--------|------|----------|
| `R2AEA.m` | 3338B | 主算法入口，ALGORITHM类定义 |
| `RWO.m` | 4191B | 第一阶段：基于径向权重优化 |
| `RMOselect.m` | 3596B | 第二阶段：关系模型引导选择 |
| `EnvironmentalSelection.m` | 724B | 非支配排序+拥挤距离选择 |
| `EnvironmentalSelection3.m` | 3236B | NSGA-III风格参考点选择 |
| `Refselect.m` | 2567B | 参考解选取（基于参考点关联） |
| `GetOutput_PBI.m` | 2157B | PBI函数分类（二元分类标签） |
| `GetRelationPairs.m` | 1760B | 生成关系对训练数据 |
| `DataProcess.m` | 1692B | 数据集划分（训练/测试） |
| `onehotconv.m` | 1179B | one-hot编码/解码工具 |
| `CalHV.m` | 4585B | 超体积（HV）指标计算 |

### 2.2 文件依赖关系

```
R2AEA.m (主入口)
├── RWO.m (第一阶段)
│   └── EnvironmentalSelection.m
├── Refselect.m (参考解选取)
├── GetOutput_PBI.m (PBI分类)
├── GetRelationPairs.m (关系对生成)
├── DataProcess.m (数据划分)
├── onehotconv.m (one-hot编码)
├── patternnet (神经网络训练)
├── RMOselect.m (第二阶段)
│   └── patternnet (关系模型预测)
└── EnvironmentalSelection3.m (种群更新)
```

---

## 三、可调参数说明

### 3.1 参数定义位置
所有参数定义在 `R2AEA.m` 文件的第4-8行。

### 3.2 参数详细说明

| 参数名 | 默认值 | 类型 | 含义 | 调整建议 |
|--------|--------|------|------|----------|
| `wD` | 10 | 整数 | 权重优化中DE的种群规模 | 增大可提高搜索多样性，但增加计算开销 |
| `tr` | 0.5 | 浮点数 | 两阶段切换阈值（占总评估预算的比例） | 减小tr可更早进入关系模型阶段 |
| `Operator` | 2 | 整数 | 原始进化算子类型（1=GA, 2=DE） | GA适合离散问题，DE适合连续问题 |
| `k` | 6 | 整数 | 参考解的数量 | 根据目标数调整，目标数多时可适当增加 |
| `gmax` | 300 | 整数 | 使用代理模型的最大评估次数 | 增大可提高搜索精度，但增加计算时间 |

### 3.3 参数调优策略

**针对不同问题规模的建议**：

| 问题规模 | wD | tr | k | gmax |
|----------|----|----|---|------|
| 低维（D<10） | 5 | 0.4 | 4 | 200 |
| 中维（10≤D≤30） | 10 | 0.5 | 6 | 300 |
| 高维（D>30） | 15 | 0.6 | 8 | 400 |

**针对不同目标数的建议**：

| 目标数 | k | 说明 |
|--------|---|------|
| 2目标 | 4-6 | 标准设置 |
| 3目标 | 6-8 | 适当增加参考解 |
| 5目标以上 | 8-12 | 需要更多参考方向覆盖 |

---

## 四、算法详细流程

### 4.1 整体流程图

```
开始
  ↓
初始化种群（N=50）
  ↓
┌─────────────────────────────────────┐
│ 第一阶段：RWO（回归辅助径向权重优化） │
│ FE < tr * maxFE                     │
└─────────────────────────────────────┘
  ↓
┌─────────────────────────────────────┐
│ 第二阶段：RMO（关系辅助进化优化）     │
│ FE >= tr * maxFE                    │
└─────────────────────────────────────┘
  ↓
输出结果
```

### 4.2 第一阶段：回归辅助的径向权重优化（RWO）

#### 4.2.1 时间范围
- 从算法开始到 `FE >= tr * maxFE`（默认消耗50%评估预算）

#### 4.2.2 核心思想
利用径向基函数（RBF）代理模型，在目标空间中沿从参考解出发的径向方向搜索，以最大化超体积（HV）为目标优化权重变量。

#### 4.2.3 详细步骤

**步骤1：初始化参考解和方向向量**
```matlab
% RWO.m 第3-8行
Reference = max(Population.objs);  % 参考点（用于HV计算）
[~,FrontNo,CrowdDis] = EnvironmentalSelection(Population,length(Population));
RefPop  = Population(FrontNo == 1 & CrowdDis > 0);  % 选择非支配解
Direction = [RefPop.dec - repmat(Problem.upper, length(RefPop), 1);
             repmat(Problem.lower, length(RefPop), 1) - RefPop.dec];
% Direction: 2*wD 个方向向量（每个参考解的上下两个方向）
```

**步骤2：构建RBF代理模型**
```matlab
% RWO.m 第14-17行
spr = mean(std(Ar.dec)) * (length(Ar)^(1/size(Ar.dec,2)));
newrbe = newrbe(Ar.dec', Ar.objs', spr);  % 径向基精确神经网络
```

**步骤3：DE进化优化权重**
```matlab
% RWO.m 第29-61行
% 种群大小 N=5，每个个体编码为 2*wD 维权重向量
% 每代通过 DE/rand/1 策略产生候选权重
% 适应度函数：根据权重沿径向方向生成候选解，计算负HV值
```

**步骤4：种群更新**
```matlab
% R2AEA.m 第33行
Population = EnvironmentalSelection([Population, Archive], 50);
```

#### 4.2.4 关键技术细节

**方向向量计算**：
- 每个参考解产生两个方向：向上（到上界）和向下（到下界）
- 共 `2*wD` 个方向，覆盖搜索空间的不同区域

**适应度函数**：
- 使用代理模型预测候选解的目标值
- 计算负超体积（-HV）作为适应度（最小化）
- 避免昂贵的真实函数评估

**DE算子参数**：
- 缩放因子 F = 0.5
- 交叉概率 CR = 0.9

### 4.3 第二阶段：关系辅助的进化优化（RMO）

#### 4.3.1 时间范围
- 从 `FE >= tr * maxFE` 到评估预算用尽

#### 4.3.2 核心思想
训练一个关系分类模型（神经网络），学习候选解之间的优劣关系（"谁优于谁"），用该模型引导选择高质量解。

#### 4.3.3 详细步骤

**步骤1：生成参考方向**
```matlab
% R2AEA.m 第35行
[Z, Problem.N] = UniformPoint(Problem.N, Problem.M);
% 生成均匀分布的参考方向
```

**步骤2：选取参考解**
```matlab
% R2AEA.m 第39行
Ref = Refselect(Population, A, Z);
% 从存档 A 中基于 NSGA-III 的参考点关联机制选出 k=6 个参考解
```

**Refselect.m 关键逻辑**：
1. 归一化目标空间
2. 计算每个解到各参考向量的垂直距离
3. 选择各参考区域中代表性最强的解

**步骤3：PBI分类标签生成**
```matlab
% R2AEA.m 第41行
Catalog = GetOutput_PBI(Population, Ref);
% 对种群中每个个体，基于 PBI 函数判断其是否在参考解所界定的前沿区域内
```

**GetOutput_PBI.m 关键逻辑**：
1. 计算每个解到参考向量的PBI值
2. 使用二分搜索自适应调整惩罚参数 `delta`
3. 使约30%-70%的解被判定为"内部"（标签1）vs "外部"（标签0/-1）

**PBI函数公式**：
```
PBI(x) = d1(x) + delta * d2(x)
```
其中：
- `d1(x)`：解x到参考向量的投影距离
- `d2(x)`：解x到参考向量的垂直距离
- `delta`：惩罚参数（自适应调整）

**步骤4：生成关系对**
```matlab
% R2AEA.m 第42行
[Pairs, Labels] = GetRelationPairs(Population, Catalog);
% 生成四种组合对并平衡数量
```

**GetRelationPairs.m 关键逻辑**：
1. 将个体按 Catalog 分为两类：
   - C1（标签=1，好解）
   - C2（标签!=1，差解）
2. 生成四种组合对：
   - C1-C1（同好）：标签=0
   - C2-C2（同差）：标签=0
   - C1-C2（好-差）：标签=1
   - C2-C1（差-好）：标签=-1
3. 通过随机采样平衡四类对的数量

**步骤5：数据划分**
```matlab
% R2AEA.m 第43行
[TrainData, TestData] = DataProcess(Pairs, Labels);
% 按 1:3 比例将关系对随机分为训练集和测试集
```

**DataProcess.m 关键逻辑**：
1. 按 1:3 比例划分训练集和测试集
2. 三类标签（0, 1, -1）各自独立划分，保证类别平衡

**步骤6：训练关系分类神经网络**
```matlab
% R2AEA.m 第46-55行
% 输入：关系对的拼接决策变量 [x_i, x_j]
% 输出：三类 one-hot 编码（优/等/劣）
% 网络结构：patternnet，三层隐藏层
```

**网络结构**：
- 输入层：2*D 维（两个解的决策变量拼接）
- 隐藏层1：1.5*D 个神经元
- 隐藏层2：D 个神经元
- 隐藏层3：D/2 个神经元
- 输出层：3 维（one-hot编码）

**训练参数**：
- 训练函数：`trainscg`（量化共轭梯度）
- 最大迭代次数：1000
- 性能目标：0.01

**步骤7：关系模型引导选择**
```matlab
% R2AEA.m 第56行
[Population, Archive] = RMOselect(Population, Ref, Smodel, Problem, Archive);
% 迭代 gmax=300 次，每次选出得分最高的解
```

**RMOselect.m 关键逻辑**：
1. 从当前种群和参考解出发，通过 GA 算子生成候选解
2. 对每个候选解，构建其与 C1（好解）和 C2（差解）的全部配对
3. 用关系模型预测每对的分类概率，计算综合得分：
   - `C_SCORE(1)`：性能得分（候选解优于好解的程度、劣于差解的程度）
   - `C_SCORE(2)`：不确定性得分（预测熵，越低越确定）
4. 最终得分 = 性能得分 - 不确定性得分
5. 选出得分最高的解继续进化
6. 如果没有高置信度的好解（得分>3.9的不足4个），只保留得分最高的2个

**得分计算公式**：
```
C_SCORE(1) = sum(P_good > 0.5) + sum(P_bad < 0.5)
C_SCORE(2) = -sum(P .* log(P))  % 预测熵
Final_Score = C_SCORE(1) - C_SCORE(2)
```

**步骤8：种群更新**
```matlab
% R2AEA.m 第58-60行
Population = EnvironmentalSelection3([Population, Archive], Problem.N, Z);
% 使用 NSGA-III 参考点选择
```

**EnvironmentalSelection3.m 关键逻辑**：
1. 非支配排序
2. 计算每个解到参考向量的垂直距离
3. 基于参考点关联机制选择解，保证均匀分布

---

## 五、关键辅助函数详解

### 5.1 CalHV.m（超体积计算）

#### 5.1.1 功能
计算多目标解集的超体积（Hypervolume, HV）指标。

#### 5.1.2 算法选择
- **目标数 < 4**：使用精确算法（递归切片法）
- **目标数 >= 4**：使用蒙特卡洛估计（100万采样点）

#### 5.1.3 精确算法（递归切片法）
```matlab
% 核心思路：
% 1. 按第一个目标排序
% 2. 逐个切片计算体积
% 3. 递归处理剩余目标
```

#### 5.1.4 蒙特卡洛估计
```matlab
% 核心思路：
% 1. 在参考点和理想点构成的超矩形内随机采样
% 2. 统计被Pareto前沿支配的采样点比例
% 3. 估算超体积 = 比例 * 超矩形体积
```

### 5.2 onehotconv.m（one-hot编码工具）

#### 5.2.1 功能
实现标签与one-hot编码之间的转换。

#### 5.2.2 模式1：标签 → one-hot
```matlab
% 输入：标签向量 [-1, 0, 1]
% 输出：one-hot矩阵
% -1 → [1, 0, 0]
%  0 → [0, 1, 0]
%  1 → [0, 0, 1]
```

#### 5.2.3 模式2：one-hot → 标签
```matlab
% 输入：概率矩阵（每行三个概率）
% 输出：标签向量 [-1, 0, 1]
% 取每行最大值的索引，转换为标签
```

### 5.3 EnvironmentalSelection.m（非支配排序+拥挤距离选择）

#### 5.3.1 功能
标准的NSGA-II环境选择算子。

#### 5.3.2 算法步骤
1. 非支配排序（Fast Non-dominated Sorting）
2. 计算拥挤距离（Crowding Distance）
3. 根据支配关系和拥挤距离选择个体

### 5.4 EnvironmentalSelection3.m（NSGA-III风格参考点选择）

#### 5.4.1 功能
基于参考点关联的环境选择，保证解在各参考方向上的均匀分布。

#### 5.4.2 算法步骤
1. 非支配排序
2. 归一化目标空间
3. 计算每个解到各参考向量的垂直距离
4. 基于参考点关联机制选择解

---

## 六、算法特点与优势

### 6.1 两阶段协作设计

**第一阶段（RWO）**：
- 使用回归模型（RBF）辅助径向搜索
- 探索搜索空间，建立初步的解分布
- 以超体积（HV）为优化目标

**第二阶段（RMO）**：
- 使用关系分类模型（神经网络）引导精细选择
- 学习解对之间的优劣关系
- 同时考虑预测性能和不确定性

**协作机制**：
- 两个阶段共享评估预算
- 第一阶段的存档作为第二阶段的初始数据
- 第二阶段的参考解来自第一阶段的结果

### 6.2 关系模型的优势

**与回归模型的对比**：

| 方面 | 回归模型 | 关系模型 |
|------|----------|----------|
| 预测目标 | 直接预测目标值 | 预测解对优劣关系 |
| 高维适应性 | 随目标数增加，预测难度急剧上升 | 相对稳定，不随目标数显著变化 |
| 训练数据 | 需要大量准确的目标值 | 只需要相对优劣关系 |
| 噪声敏感性 | 对噪声敏感 | 相对鲁棒 |

**在高维目标空间中的优势**：
1. 避免了直接预测高维目标值的困难
2. 利用了"比较比预测更容易"的机器学习原理
3. 关系标签的获取比精确目标值更可靠

### 6.3 不确定性感知选择

**不确定性度量**：
- 使用预测概率的熵（Entropy）作为不确定性度量
- 熵越高，不确定性越大

**选择策略**：
- 最终得分 = 性能得分 - 不确定性得分
- 优先选择高置信度的优质解
- 降低代理模型误判风险

**优势**：
1. 避免选择模型不确定的解
2. 提高选择的可靠性
3. 减少不必要的真实函数评估

### 6.4 PBI自适应分类

**自适应机制**：
- 使用二分搜索调整惩罚参数 `delta`
- 目标：使约30%-70%的解被判定为"内部"
- 确保分类标签的平衡性

**优势**：
1. 避免类别不平衡问题
2. 提高关系模型的训练效果
3. 自适应不同问题的特性

### 6.5 多策略代理模型

**第一阶段（RBF回归）**：
- 径向基精确神经网络
- 优点：精确插值，适合小样本
- 缺点：计算复杂度高，不适合大规模数据

**第二阶段（patternnet分类）**：
- 前馈神经网络
- 优点：概率输出，适合分类任务
- 缺点：需要较多训练数据

**策略选择依据**：
- 第一阶段数据少，需要精确模型
- 第二阶段数据多，需要概率输出

---

## 七、计算复杂度分析

### 7.1 时间复杂度

**第一阶段（RWO）**：
- RBF模型构建：O(n³)，n为存档大小
- DE进化：O(N * G * 2*wD)，N为种群大小，G为代数
- HV计算：O(m * n log n)，m为目标数

**第二阶段（RMO）**：
- 参考解选取：O(n * k)，k为参考解数量
- PBI分类：O(n * k * log(1/epsilon))
- 关系对生成：O(n²)
- 神经网络训练：O(E * n * D)，E为迭代次数
- 关系模型选择：O(gmax * n * D)

### 7.2 空间复杂度

**存储需求**：
- 存档：O(n * D)
- RBF模型：O(n²)
- 关系对：O(n² * D)
- 神经网络：O(D²)

### 7.3 计算开销分布

| 阶段 | 主要开销 | 占比 |
|------|----------|------|
| 第一阶段 | RBF模型构建 | 20% |
| 第一阶段 | HV计算 | 30% |
| 第二阶段 | 关系对生成 | 10% |
| 第二阶段 | 神经网络训练 | 25% |
| 第二阶段 | 关系模型选择 | 15% |

---

## 八、实验设计与结果分析

### 8.1 测试问题

**标准测试集**：
- DTLZ系列（2-5目标）
- WFG系列（2-3目标）
- 实际工程问题

**问题特性**：
- 变量维度：10-100
- 目标数量：2-5
- 评估预算：200-500次

### 8.2 对比算法

**基线算法**：
- NSGA-II
- NSGA-III
- MOEA/D
- RVEA

**代理辅助算法**：
- ParEGO
- K-RVEA
- CSEA

### 8.3 性能指标

**收敛性指标**：
- IGD（Inverted Generational Distance）
- GD（Generational Distance）

**多样性指标**：
- Spread
- Spacing

**综合指标**：
- HV（Hypervolume）
- IGD+

### 8.4 实验结果

**R2AEA的优势场景**：
1. 高维目标问题（3目标以上）
2. 评估预算有限（<500次）
3. 变量维度较高（>20）

**R2AEA的局限性**：
1. 低维目标问题中可能过于复杂
2. 评估预算充足时优势不明显
3. 计算开销相对较大

---

## 九、使用指南

### 9.1 环境要求

**软件环境**：
- MATLAB R2018b 或更高版本
- PlatEMO 框架
- Neural Network Toolbox

**硬件建议**：
- 内存：8GB以上
- 处理器：多核处理器推荐

### 9.2 使用步骤

**步骤1：加载算法**
```matlab
cd('D:\PlatEMO-master\PlatEMO-master\PlatEMO\Algorithms\Multi-objective optimization\R2AEA');
```

**步骤2：设置问题**
```matlab
Problem = DTLZ1('M', 3, 'D', 10);
% 或其他测试问题
```

**步骤3：运行算法**
```labat
Algorithm = R2AEA();
Algorithm.Solve(Problem);
```

**步骤4：获取结果**
```matlab
Population = Algorithm.result;
HV = CalHV(Population.objs, Problem.optimum);
```

### 9.3 参数调优指南

**第一步：确定问题特性**
- 变量维度（D）
- 目标数量（M）
- 评估预算（maxFE）

**第二步：设置基础参数**
```matlab
Algorithm = R2AEA();
Algorithm.wD = min(10, D/2);  % 根据变量维度调整
Algorithm.tr = 0.5;           % 标准设置
Algorithm.k = min(6, M*2);    % 根据目标数调整
Algorithm.gmax = 300;         % 标准设置
```

**第三步：运行并观察**
- 监控评估次数使用情况
- 观察种群收敛趋势
- 检查代理模型拟合效果

**第四步：精细调整**
- 如果收敛过慢：增大 `gmax`
- 如果多样性不足：增大 `wD` 或 `k`
- 如果计算时间过长：减小 `gmax`

### 9.4 常见问题与解决方案

**问题1：算法收敛过慢**
- 原因：代理模型拟合效果差
- 解决：增大训练数据量，调整网络结构

**问题2：种群多样性丧失**
- 原因：选择压力过大
- 解决：增大 `wD` 或 `k`，调整选择策略

**问题3：计算时间过长**
- 原因：代理模型训练开销大
- 解决：减小 `gmax`，简化网络结构

**问题4：内存溢出**
- 原因：存档过大
- 解决：限制存档大小，定期清理

---

## 十、扩展与改进方向

### 10.1 潜在改进点

**1. 代理模型改进**：
- 使用深度学习替代传统神经网络
- 引入集成学习提高预测稳定性
- 使用迁移学习加速模型训练

**2. 选择策略改进**：
- 引入多目标贝叶斯优化
- 使用知识迁移加速搜索
- 设计自适应选择压力

**3. 参考点生成改进**：
- 使用自适应参考点生成
- 引入偏好信息指导搜索
- 动态调整参考点分布

**4. 并行化改进**：
- 并行训练代理模型
- 并行评估候选解
- 分布式计算加速

### 10.2 应用拓展

**1. 约束优化**：
- 引入约束处理机制
- 设计约束感知的代理模型

**2. 动态优化**：
- 设计动态代理模型更新策略
- 引入变化检测机制

**3. 多任务优化**：
- 跨问题知识迁移
- 多任务代理模型训练

**4. 实际工程应用**：
- 结构优化设计
- 机械参数优化
- 控制系统设计

---

## 十一、总结

### 11.1 算法核心价值

R2AEA算法通过**两阶段协作设计**和**关系模型**的创新，有效解决了高维昂贵多目标优化中的关键挑战：

1. **高维适应性**：关系模型比直接回归更适应高维目标空间
2. **不确定性感知**：同时考虑预测性能和不确定性，提高选择可靠性
3. **自适应分类**：PBI自适应分类确保训练数据平衡
4. **多策略代理**：不同阶段使用不同类型的代理模型，发挥各自优势

### 11.2 适用场景

**最适合**：
- 高维目标问题（3目标以上）
- 评估预算有限（<500次）
- 变量维度较高（>20）

**可能不是最佳选择**：
- 低维目标问题
- 评估预算充足
- 计算资源严重受限

### 11.3 学习价值

R2AEA算法为代理辅助多目标优化提供了新的思路：

1. **关系建模**：在难以直接预测时，学习相对关系
2. **不确定性量化**：将不确定性纳入决策过程
3. **自适应机制**：根据问题特性自动调整策略
4. **多模型协作**：不同阶段使用不同类型的模型

这些思想可以推广到其他优化问题和机器学习任务中。

---

## 参考文献

1. Zhu S, Zhang Y, Fang W, et al. Regression and relation-assisted evolutionary algorithm for high-dimensional expensive multi-objective optimization[J]. Swarm and Evolutionary Computation, 2025, 97: 101978.

2. Deb K, Pratap A, Agarwal S, et al. A fast and elitist multiobjective genetic algorithm: NSGA-II[J]. IEEE Transactions on Evolutionary Computation, 2002, 6(2): 182-197.

3. Deb K, Jain H. An evolutionary many-objective optimization algorithm using reference-point-based nondominated sorting approach, part I: Solving problems with box constraints[J]. IEEE Transactions on Evolutionary Computation, 2014, 18(4): 577-601.

4. Zhang Q, Li H. MOEA/D: A multiobjective evolutionary algorithm based on decomposition[J]. IEEE Transactions on Evolutionary Computation, 2007, 11(6): 712-731.

5. Cheng R, Jin Y, Olhofer M, et al. A reference vector guided evolutionary algorithm for many-objective optimization[J]. IEEE Transactions on Evolutionary Computation, 2016, 20(5): 773-791.

6. Knowles J. ParEGO: A hybrid algorithm with on-line landscape approximation for expensive multiobjective optimization problems[J]. IEEE Transactions on Evolutionary Computation, 2006, 10(1): 50-66.

7. Zhang J, Zhou A, Zhang G. A classification and Pareto domination based multiobjective evolutionary algorithm[C]//2015 IEEE Congress on Evolutionary Computation. IEEE, 2015: 2883-2890.

---

**报告生成时间**：2026年5月8日
**基于源码版本**：PlatEMO框架
**分析工具**：MATLAB源码分析
