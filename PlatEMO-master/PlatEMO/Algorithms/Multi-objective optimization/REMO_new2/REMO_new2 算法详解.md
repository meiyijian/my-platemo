# REMO_new2 算法详解

## 一、算法背景与定位

REMO（Relation learning and prEdiction for expensive Multi-objective Optimization）是一种用于昂贵多目标优化（Expensive Multi-objective Optimization, EMO）的代理模型辅助进化算法。其核心思想不是直接预测单个解的目标值，而是学习两个解之间的"关系"（谁支配谁、是否同优劣），从而把回归问题转化为分类问题。

REMO_new2 是在原始 REMO（2022 年提出）的基础上做了两处关键扩展：

1. 引入 HPC（Hybrid PBI Classification）混合分类策略，结合自适应参考向量场与动态参考解，对种群打分；
2. 用 PBI（Penalty based Boundary Intersection）距离和动态权重 α 平衡全局参考向量场与局部动态标签的影响。

整个算法适用于以下场景：

| 场景维度       | 适用范围                                     |
| -------------- | -------------------------------------------- |
| 决策变量维度 D | 任意（D≤10 时种群规模 N=11D-1，否则 N=100） |
| 目标维度 M     | 多目标 / 高维多目标（many-objective）        |
| 评估代价       | 昂贵（expensive），即真实评估次数受预算限制  |
| 标签           | `<multi/many> <real> <expensive>`          |

## 二、文件组成与依赖关系

REMO_new2 文件夹下共 9 个 m 文件，调用关系如下：

```
REMO_new2.m  (主入口)
├── HybridPBI_Classification.m   混合分类，输出好/坏标签和参考解
│   ├── UniformPoint              （PlatEMO 公共函数）
│   ├── NDSort                    （PlatEMO 公共函数）
│   ├── kmeans                    （MATLAB 内置）
│   ├── RefSelect.m               动态参考解选择
│   └── GetOutput_PBI.m           PBI 阈值划分动态标签
├── GetRelationPairs.m            构造关系对训练样本
├── DataProcess.m                 训练集 / 测试集划分
├── onehotconv.m                  one-hot 编码 / 解码
├── patternnet / train            （MATLAB 神经网络工具箱）
├── RSurrogateAssistedSelection.m 代理模型辅助选择
│   ├── OperatorGA                （PlatEMO 公共算子）
│   └── model_select (内部函数)   候选解打分
├── RefSelect.m                   环境选择
└── Delequalsamples.m             删除等价样本（实际未在主流程调用，备用）
```

## 三、整体流程

### 3.1 主循环伪代码

```
输入: 问题 Problem, 参数 k=6, gmax=3000
1. 初始化:
   N = (D≤10 ? 11D-1 : 100)
   PopDec ← 拉丁超立方采样
   Population ← 真实评估初始种群
   Archive ← Population
2. while 未达到评估预算:
   2.1 ratio = FE / maxFE   // 进化比例
   2.2 [good_idx, bad_idx, Catalog, confidence, Ref] = HybridPBI_Classification(Population, ratio, ...)
   2.3 [XXs, YYs] = GetRelationPairs(Population.decs, Catalog)   // 构造关系对
   2.4 [TrainIn, TrainOut, TestIn, TestOut] = DataProcess(XXs, YYs)
   2.5 训练 patternnet 神经网络（三隐含层），评估测试误差 p_err
   2.6 Smodel ← {X, Y, mp_struct, net, p_err}
   2.7 Next = RSurrogateAssistedSelection(Problem, Ref, Population.decs, gmax, Smodel)
   2.8 if Next 非空: Archive ← [Archive, Problem.Evaluation(Next)]   // 真实评估
   2.9 Population = RefSelect(Archive, Problem.N)                     // 环境选择
3. 输出 Archive
```

### 3.2 流程图（简化）

```
        ┌──────────────────────┐
        │   拉丁超立方采样初始化  │
        └──────────┬───────────┘
                   ▼
        ┌──────────────────────┐
   ┌───►│  HPC 混合分类（打分）  │
   │    │   产生 Catalog & Ref  │
   │    └──────────┬───────────┘
   │               ▼
   │    ┌──────────────────────┐
   │    │ 关系对样本生成 GetRP  │
   │    └──────────┬───────────┘
   │               ▼
   │    ┌──────────────────────┐
   │    │  patternnet 训练分类  │
   │    └──────────┬───────────┘
   │               ▼
   │    ┌──────────────────────┐
   │    │ 代理模型辅助 GA 搜索  │
   │    │ (RSurrogateAssist..) │
   │    └──────────┬───────────┘
   │               ▼
   │    ┌──────────────────────┐
   │    │   真实评估候选解       │
   │    │   Archive 累积         │
   │    └──────────┬───────────┘
   │               ▼
   │    ┌──────────────────────┐
   └────┤  RefSelect 环境选择   │
        │   产生下一代 Population│
        └──────────────────────┘
```

## 四、关键模块详解

### 4.1 HybridPBI_Classification（混合 PBI 分类）

文件：`HybridPBI_Classification.m`

这是 REMO_new2 相对于原版 REMO 最核心的改动。它通过三种信号（参考向量场、动态参考解、置信度）共同对种群打分。

**步骤一：自适应参考向量场 V**

```
若 M ≤ 3 或 N < 50:
    V = UniformPoint(Nref, M, 'ILD')   // 均匀向量足够
否则:
    V = AdaptiveReferenceVectors(PopObj, Nref)
    其中 AdaptiveReferenceVectors 步骤为:
      a) NDSort 提取非支配解 ParetoObj
      b) 若非支配解过少 (<max(10,Nref/2))，回退均匀向量
      c) 对 ParetoObj 按目标范围归一化
      d) K-means 聚类，得到 nClusters 个簇中心
      e) 簇中心映射回原空间，归一化为单位向量
```

设计动机：高维多目标问题中，均匀分布的参考向量未必匹配真实 Pareto 前沿形状；用非支配解聚类生成的参考向量能贴近当前前沿分布。

**步骤二：PBI 距离与全局得分 score_v**

对种群中每个解 i：

1. 找到与之夹角最小的参考向量 vi（cosine 最大）；
2. 计算 d1 = 解到理想点 Zmin 沿 vi 方向的投影长度；
3. 计算 d2 = 解到投影点的垂直距离；
4. PBI_v(i) = d1 + θ·d2（θ=5）；
5. score_v(i) = 1 / (1 + PBI_v(i))。

公式：

```
d1 = (PopObj_i - Zmin) · w / ||w||
d2 = || PopObj_i - (Zmin + d1·w) ||
score_v = 1 / (1 + d1 + θ·d2)
```

**步骤三：动态参考解 Ref 与动态标签 label_dyn**

```
Ref = RefSelect(Population, k)         // RSEA 策略选 k 个参考解
label_dyn = GetOutput_PBI(PopObj, RefObj)
```

`GetOutput_PBI` 内部用二分搜索自适应 δ，使被标记为"好"的比例 r 落在 [0.3, 0.7]，避免类别极度不均衡。

**步骤四：融合得分 score_hybrid**

```
alpha = 1 - ratio    // 早期 alpha 接近 1，后期接近 0
score_hybrid = alpha * score_v + (1-alpha) * label_dyn
```

含义：

* 早期（ratio 小，alpha 大）侧重全局参考向量场，关注空间整体分布；
* 后期（ratio 大，alpha 小）侧重动态参考解的局部 PBI 标签，关注前沿精细收敛。

代码中作者先写了 `alpha = ratio` 然后立刻覆盖为 `alpha = 1 - ratio`，注释说明取反是为了符合"早期全局、后期局部"的原始设计意图。

**步骤五：置信度与好/坏选择**

```
confidence = 1 - |score_v - label_dyn|       // 两个信号一致则置信度高
good_num = ceil(N/4); bad_num = good_num
按 score_hybrid 降序排序:
  前 N/4 → good_idx (Catalog=true)
  后 N/4 → bad_idx
  中间   → Catalog=false（与原 REMO 兼容，归并到坏类）
```

输出：`good_idx, bad_idx, Catalog (logical N×1), confidence, Ref`。

### 4.2 GetOutput_PBI（PBI 阈值划分）

文件：`GetOutput_PBI.m`

输入：种群目标 Pop、参考解 Ref；输出：每个解是否"好"的布尔向量。

**核心：扩展 PBI 公式带阈值 δ**

对每个参考点（取 Ref 的目标）：

```
w = Ref - Zmin（方向向量）
W = w / ||w||
g = ||P-Zmin|| · cosθ + δ · ||P-Zmin|| · sinθ
g_norm = g / ||Ref - Zmin||
```

若 g_norm > 1 则标记为坏（false），反之为好（true）。δ 越大，惩罚越大，被划入"坏"的越多。

**自适应 δ**：当用户未提供 δ 时，二分搜索 δ ∈ [-20, 20]，使得"好"的比例 r 落入 [0.3, 0.7]，循环终止条件是区间宽度 < 0.1 或比例达标。

### 4.3 RefSelect（参考解选择，RSEA 策略）

文件：`RefSelect.m`

来自 RSEA（Radar grid based Selection Evolutionary Algorithm）的环境选择策略，用于从 Population 中挑出 k 个有代表性的"参考解"。

**步骤**：

1. NDSort 非支配排序，取前若干前沿直至累计超过 k 个；
2. 目标值归一化到 [0,1]；
3. 识别极端解（基于 PBI 投影到 (1,1,...,1) 方向上最近的解）作为强制保留；
4. 计算每个解的雷达坐标：

   ```
   theta = 0, 2π/M, 4π/M, ...
   x = Σ(P · cos(theta)) / Σ(P)
   y = Σ(P · sin(theta)) / Σ(P)
   ```
5. 将雷达坐标映射到 div×div 网格（div = ceil(sqrt(k))）；
6. 迭代填充：每次从最稀疏的网格中选出收敛性 + 与已选解距离综合最优者，直到选满 k 个。

`RefSelect` 在 REMO_new2 中扮演两个角色：

* HPC 内部用 k=6 选 6 个参考解供 PBI 标签计算；
* 主流程末尾用 `RefSelect(Archive, Problem.N)` 做环境选择，从全档案选 N 个解作为下一代种群。

### 4.4 GetRelationPairs（关系对样本构造）

文件：`GetRelationPairs.m`

把分类问题转化为"关系学习"：训练样本不是单个解，而是两个解的拼接 [Xi, Xj]，标签是它们之间的关系。

**步骤**：

1. 设 C1 = Catalog==true 的好解集合，C2 = Catalog~=true 的坏解集合；
2. 用 `combvec` 生成四种笛卡尔积：C1C1、C1C2、C2C1、C2C2；
3. 删除 C1C1 和 C2C2 中"自配对"（i==i）；
4. 数据均衡：

   ```
   t_num = ceil(|C1C2| / 2)
   若 |C1C1|, |C2C2| 都足够: 各取 t_num
   若 |C1C1| 不够: |C2C2| 取 2·t_num - |C1C1|
   若 |C2C2| 不够: 同理
   ```

   保证总样本中"好坏对"占一半，"同类对"占一半。
5. 标签编码：

   | 样本类型      | 标签               |
   | ------------- | ------------------ |
   | C1C1（好-好） | 0                  |
   | C2C2（坏-坏） | 0                  |
   | C1C2（好-坏） | 1（前者优于后者）  |
   | C2C1（坏-好） | -1（前者劣于后者） |

返回：XXs（样本对矩阵 N×2D），Ls（标签向量 N×1）。

### 4.5 DataProcess（数据集划分）

文件：`DataProcess.m`

按类别分层抽样 3:1 划分训练集与测试集，避免类别失衡。

```
pha = 3/4
对每个类别 (0, +1, -1):
    随机抽 ceil(pha · 类内样本数) 进入训练集
剩下 1/4 进入测试集
最后整体打乱顺序
```

### 4.6 onehotconv（one-hot 编码 / 解码）

文件：`onehotconv.m`

模式 1（编码）:

```
1  → [1, 0, 0]
0  → [0, 1, 0]
-1 → [0, 0, 1]
```

模式 2（解码）：取 argmax 后的列号映射回 {1, 0, -1}。

注意解码代码里 `res_l(maxind==2) = 0` 这一句被默认（`zeros` 初始化），仅显式处理了 1 和 -1。

### 4.7 神经网络训练

主程序 REMO_new2.m 中：

```matlab
[TrainIn_nor, TrainIn_struct] = mapminmax(TrainIn');   % 归一化到 [-1,1]
TrainIn_nor = TrainIn_nor';
TrainOut_onehot = onehotconv(TrainOut, 1);
net = patternnet([ceil(xDim*1.5), xDim*1, ceil(xDim/2)]);
net.trainParam.showWindow = 0;
net = train(net, TrainIn_nor', TrainOut_onehot');
```

* xDim = 2D（关系对的输入维度）；
* 三层隐含层，节点数依次为 1.5·xDim、xDim、0.5·xDim；
* 输出层 3 个节点，对应类别 {+1, 0, -1}；
* 使用 MATLAB 默认的 patternnet（实质为带 softmax 输出的前馈网络），训练算法默认是 trainscg；
* `mp_struct` 保存归一化参数，预测时用 `mapminmax('apply', X', mp_struct)` 复用相同变换。

### 4.8 RSurrogateAssistedSelection（代理辅助选择）

文件：`RSurrogateAssistedSelection.m`

这是 REMO 系列利用代理模型筛选候选解的核心模块，避免每个候选都做真实评估。

**主流程**：

```
Next = OperatorGA(Problem, [Input; Ref.decs], {1, 15, 1, 5})   % 初始 GA 子代
i = 0
while i < gmax:
    [sorted_idx, ~] = model_select(Smodel, Next)               % 神经网络打分
    Input = Next(sorted_idx(1:|Ref|), :)                        % 留下评分最好的 |Ref| 个
    Next  = OperatorGA(Problem, [Input; Ref.decs], {1, 15, 1, 5})
    i = i + size(Next, 1)
最后:
    [~, scores] = model_select(Smodel, Next)
    若 sum(scores>3.9) < 4:
        取 scores 最大的前 4 个作为 Next
    否则:
        取所有 scores>3.9 的解作为 Next
```

GA 算子参数 `{1, 15, 1, 5}` 对应 SBX 交叉概率 1、SBX 分布指数 15、多项式变异概率 1、变异分布指数 5。

**model_select 内部打分机制**

输入：候选解 Next（行向量集合），Smodel 中存有训练数据 X 与标签 Y。

设 C1_data = X(Y==1) 为好解集合，C2_data = X(Y~=1) 为坏解集合。对每个候选解 Xi，构造 4 类样本对让网络预测：

| 样本对   | 含义                 |
| -------- | -------------------- |
| [C1, Xi] | 好解 在前，候选 在后 |
| [Xi, C1] | 候选 在前，好解 在后 |
| [C2, Xi] | 坏解 在前，候选 在后 |
| [Xi, C2] | 候选 在前，坏解 在后 |

总测试样本数 = 2·(C1_num + C2_num)·|Next|。

网络输出 3 类概率 [p+1, p0, p-1]，其中 +1 表示前者优于后者、-1 表示前者劣于后者、0 表示同类。

打分规则按下表累加：

| 样本对                 | C_SCORE(1) (Xi 好的证据) | C_SCORE(2) (Xi 坏的证据) |
| ---------------------- | ------------------------ | ------------------------ |
| [C1, Xi] 预测 pre_C1Xi | pre_C1Xi(2)+pre_C1Xi(3)  | pre_C1Xi(1)              |
| [Xi, C1] 预测 pre_XiC1 | pre_XiC1(2)+pre_XiC1(1)  | pre_XiC1(3)              |
| [C2, Xi] 预测 pre_C2Xi | pre_C2Xi(3)              | pre_C2Xi(2)+pre_C2Xi(1)  |
| [Xi, C2] 预测 pre_XiC2 | pre_XiC2(1)              | pre_XiC2(2)+pre_XiC2(3)  |

最终 `score(Xi) = C_SCORE(1) - C_SCORE(2)`，得分越高表示 Xi 越接近"好类"。

每对样本贡献 ≤ 2 分，4 类对累计最多 8 分。代码中阈值 3.9 表示需要候选具备较强的"好类"证据。

## 五、关键超参数与数据流

### 5.1 算法超参数

| 参数       | 默认值     | 含义                                   |
| ---------- | ---------- | -------------------------------------- |
| k          | 6          | 参考解数量（HPC 内 RefSelect 选解数）  |
| gmax       | 3000       | 内层代理辅助 GA 累计样本上限           |
| theta (θ) | 5          | PBI 惩罚系数                           |
| Nref       | N          | 参考向量个数（默认等于种群规模）       |
| pha        | 3/4        | 训练集占比                             |
| 阈值 3.9   | 内部硬编码 | RSurrogateAssistedSelection 中筛选阈值 |

### 5.2 主要数据结构

| 名称       | 维度                     | 说明                                                |
| ---------- | ------------------------ | --------------------------------------------------- |
| Population | N×1 SOLUTION            | 当前工作种群                                        |
| Archive    | (N+评估次数)×1 SOLUTION | 累积所有真实评估解                                  |
| Catalog    | N×1 logical             | 好（true）/ 坏（false）标签                         |
| Ref        | k×1 SOLUTION            | 动态参考解                                          |
| XXs        | n_pair × 2D             | 关系对输入（拼接两个解决策变量）                    |
| YYs        | n_pair × 1              | 关系标签 ∈ {-1, 0, +1}                             |
| Smodel     | struct                   | 训练好的代理模型，包含 net、归一化结构、X、Y、p_err |
| Next       | 候选数 × D              | 代理筛选出的候选决策变量，再交真实评估              |

## 六、与原版 REMO 的差异

| 维度          | 原版 REMO             | REMO_new2                         |
| ------------- | --------------------- | --------------------------------- |
| 好/坏分类来源 | 仅基于参考解 PBI 标签 | 参考向量场 + 动态参考解的混合 PBI |
| 参考向量      | 固定均匀向量或参考解  | 自适应（K-means 聚类非支配解）    |
| 权重融合      | 无                    | α=1-ratio 自适应权重             |
| 置信度        | 无                    | 输出 confidence 用于后续评估      |
| 好/坏比例     | 通常按 PBI 阈值       | 固定为各 N/4                      |
| 中间解处理    | 与坏类合并            | 同样合并（保持兼容）              |

升级动机：

1. 高维多目标下均匀向量与真实前沿不匹配，K-means 自适应向量更贴合；
2. 早期收敛阶段需要全局视野（score_v 占主导），后期精细搜索需要局部视野（label_dyn 占主导），ratio 驱动的 α 自动切换；
3. confidence 信号为后续可能的不确定度感知扩展留口子（当前主流程未直接使用）。

## 七、复杂度分析

设 N 为种群规模，D 为决策变量维度，M 为目标维度，G 为代理辅助选择内层迭代数（≈ gmax/N）。

| 模块                        | 复杂度                                                   |
| --------------------------- | -------------------------------------------------------- |
| HybridPBI_Classification    | O(N·M·Nref + N²) （含 K-means）                       |
| GetRelationPairs            | O((                                                      |
| 神经网络训练                | 与 patternnet 实现相关，单 epoch O(n_pair·xDim·hidden) |
| RSurrogateAssistedSelection | O(G ·                                                   |
| RefSelect 环境选择          | O(                                                       |

注意：N² 级别的关系对生成在 N 较大时可能成为瓶颈，所以代码中通过 `t_num = ceil(|C1C2|/2)` 做了下采样。

## 八、典型调用示例

在 PlatEMO 中调用方式：

```matlab
platemo('algorithm', @REMO_new2, ...
        'problem',   @DTLZ2, ...
        'N',         100, ...
        'M',         3, ...
        'D',         10, ...
        'maxFE',     300);
```

* 由于昂贵优化的特性，maxFE 通常设置为几百次评估；
* 输出结果是 Archive，包含所有真实评估过的解；
* 算法实际"演化"的种群规模由 N 决定（D≤10 时 11D-1，否则 100），与外部传入的 N 取较小者。

## 九、使用注意事项

1. **MATLAB 神经网络工具箱**是硬依赖，`patternnet`、`train`、`mapminmax` 缺一不可；
2. **K-means 失败回退**：HybridPBI_Classification 中对聚类失败、目标范围为 0、非支配解过少均做了回退到均匀向量的处理；
3. **`Delequalsamples.m` 在主流程中未被调用**，是从原 REMO 保留的工具函数，可在需要时手工剔除标签为 0 的样本对；
4. **`alpha` 取反逻辑**：HybridPBI_Classification.m 第 47–49 行先赋值 `alpha = ratio` 再覆盖为 `alpha = 1 - ratio`，前一行可视为开发过程中的注释痕迹，最终生效的是后者；
5. **score 阈值 3.9 是经验值**，对应理想情况下"非常好"的候选解（C_SCORE(1) 接近上界 4 而 C_SCORE(2) 接近下界 0）；
6. **种群规模 N 与外部传入的 Problem.N 不同**：内部 N 用于代理学习，环境选择阶段才回到 Problem.N。

## 十、算法流程关键节点示意

```
真实评估                       代理评估（不消耗 FE）
  ┌─────────┐                   ┌──────────────┐
  │ 初始化  │                   │ patternnet   │
  │ N 个解  │ ────► Archive ──► │ 关系预测     │
  └────┬────┘          ▲        └──────┬───────┘
       │               │               │
       ▼               │               ▼
  ┌─────────┐          │        ┌──────────────┐
  │ 真实    │          │        │ GA 内循环     │
  │ 评估    │ ◄────────┴────────┤ + 代理打分    │
  │ Next    │                    │ (≤ gmax 次)   │
  └─────────┘                    └──────────────┘
                                       ▲
                                       │
                                ┌──────┴───────┐
                                │ HPC 分类生成  │
                                │ Catalog & Ref │
                                └───────────────┘
```

每外层循环消耗 |Next|（最多 4 个）次真实评估，但通过内层 gmax 次代理预测高效筛选，使得有限预算下尽可能找到 Pareto 前沿上的解。

## 十一、参考文献

1. Hao H, Zhou A, Qian H, et al. Expensive multiobjective optimization by relation learning and prediction. IEEE Transactions on Evolutionary Computation, 2022.
2. Tian Y, Cheng R, Zhang X, He C, Jin Y. Guiding evolutionary multiobjective optimization with generic front modeling. IEEE Transactions on Cybernetics, 2020.（RSEA 雷达网格策略）
3. Zhang Q, Li H. MOEA/D: A multiobjective evolutionary algorithm based on decomposition. IEEE Transactions on Evolutionary Computation, 2007.（PBI 分解原理）
4. Tian Y, Cheng R, Zhang X, Jin Y. PlatEMO: A MATLAB platform for evolutionary multi-objective optimization. IEEE Computational Intelligence Magazine, 2017, 12(4): 73–87.
