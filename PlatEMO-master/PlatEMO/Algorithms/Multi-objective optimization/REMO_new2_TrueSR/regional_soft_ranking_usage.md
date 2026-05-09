# 区域化 Soft Ranking 两条路线实现说明

本目录新增了两条区域化 soft ranking 实验算法：

- `REMO_new2_RegionalSR_A`
- `REMO_new2_RegionalSR_B`

两者都面向 5-20 目标昂贵优化，核心区别在于区域信息如何进入代理模型。

---

## 路线 A：全局模型 + 参考向量上下文

入口文件：

```text
REMO_new2_RegionalSR_A.m
```

训练样本形式：

```matlab
[x_i, x_j, w_r] -> P_r(x_i better than x_j)
```

其中：

- `x_i, x_j` 是两个解的决策变量；
- `w_r` 是第 `r` 个参考向量；
- 标签由区域 APD 分数差生成：

```matlab
P_r(i,j) = sigmoid(alphaSoft * (q_i^r - q_j^r))
```

这里 `q_i^r = -APD_i^r`，表示解 `i` 在参考向量区域 `r` 下的局部质量。

适用场景：

- 样本较少；
- 不希望训练太多局部模型；
- 希望模型共享不同区域之间的信息。

运行示例：

```matlab
platemo('algorithm',{@REMO_new2_RegionalSR_A,6,3000,12000,6,12,100,2,25},...
    'problem',@DTLZ2,'M',10,'D',14,'maxFE',300)
```

参数含义：

```matlab
k           = 6;      % variation reference solutions
gmax        = 3000;   % surrogate evaluations
pairMax     = 12000;  % max regional pairs
alphaSoft   = 6;      % soft label slope
anchorNum   = 12;     % anchors per active region
Nref        = 100;    % reference vector count
neighborNum = 2;      % neighbor regions for local pool expansion
maxRegions  = 25;     % active regions used in surrogate selection
```

---

## 路线 B：每个区域一个局部模型

入口文件：

```text
REMO_new2_RegionalSR_B.m
```

训练样本形式：

```matlab
[x_i, x_j] -> P_r(x_i better than x_j)
```

每个参考向量区域 `r` 单独训练一个局部 soft ranking 模型。候选解会被多个局部模型打分，最终取其在最合适区域中的最大胜率，并在真实评价前做区域去重选择。

适用场景：

- 每个参考区域有足够样本；
- 想强化 decomposition / local ranking 思想；
- 希望后续扩展为局部 ensemble 或局部不确定性模型。

运行示例：

```matlab
platemo('algorithm',{@REMO_new2_RegionalSR_B,6,3000,12000,6,12,100,2,20},...
    'problem',@DTLZ2,'M',10,'D',14,'maxFE',300)
```

参数含义：

```matlab
k           = 6;
gmax        = 3000;
pairMax     = 12000;
alphaSoft   = 6;
anchorNum   = 12;
Nref        = 100;
neighborNum = 2;
maxModels   = 20;     % maximum local regional models
```

---

## 共用核心函数

```text
CreateReferenceVectors_RegionalSR.m
BuildRegionalInfo_RegionalSR.m
GetRegionalSoftRelationPairs_A.m
GetRegionSoftPairs_RegionalSR.m
TrainRegionalSoftModels_B.m
RSurrogateAssistedSelection_RegionalSR_A.m
RSurrogateAssistedSelection_RegionalSR_B.m
SelectTopByRegion_RegionalSR.m
```

其中 `BuildRegionalInfo_RegionalSR.m` 会计算：

- 归一化目标值；
- 每个解关联的参考向量区域；
- 每个解到每个参考向量的角度；
- APD 矩阵；
- 区域局部质量矩阵 `localScoreMatrix = -APD`。

---

## 当前 smoke test

已通过小预算 5 目标 DTLZ2 测试：

```matlab
platemo('algorithm',{@REMO_new2_RegionalSR_A,4,20,200,4,4,12,1,4},...
    'problem',@DTLZ2,'M',5,'D',7,'maxFE',90)

platemo('algorithm',{@REMO_new2_RegionalSR_B,4,20,200,4,4,12,1,3},...
    'problem',@DTLZ2,'M',5,'D',7,'maxFE',90)
```

两条路线都能完成运行。

---

## 实验建议

先用小规模验证：

```text
DTLZ2, DTLZ4
M = 5, 10
maxFE = 300
```

建议对比：

```text
REMO_new2
REMO_new2_TrueSR
REMO_new2_RegionalSR_A
REMO_new2_RegionalSR_B
```

如果路线 A 优于 TrueSR，说明“参考向量上下文”有效。如果路线 B 优于路线 A，说明局部区域模型值得继续往 decomposition 方向发展；如果 B 不稳定，则说明局部样本不足，需要 ensemble 或邻域共享。

