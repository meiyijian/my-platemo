# REMO_new2_AdaMao_HPC 自适应参考向量修复设计

日期：2026-07-12

## 1. 目标

在不修改现有 `Algorithms/Multi-objective optimization/REMO_new2_AdaMaO` 目录的前提下，新建独立算法目录：

```text
Algorithms/Multi-objective optimization/REMO_new2_AdaMao_HPC
```

新算法只针对混合 PBI 中 `AdaptiveReferenceVectors` 的两个问题进行修复：

1. 当 `Nref` 接近种群规模时，`nClusters=min(Nref,nPareto)` 容易令聚类数等于样本数，K-means 退化为“一点一簇”；
2. 聚类中心不足 `Nref` 时，原实现通过 `repmat` 重复中心，产生重复参考向量且不增加方向覆盖。

本次不处理目标平移、尺度一致性、球面聚类、前沿稳定性门控等其他问题，避免扩大改动范围。

## 2. 目录与算法隔离

### 2.1 新目录

完整复制源目录中的算法运行文件到 `REMO_new2_AdaMao_HPC`，源目录保持字节级不变。

### 2.2 独立算法入口

将复制后的主算法文件改名为：

```text
REMO_new2_AdaMao_HPC.m
```

并将 MATLAB 类名同步改为：

```matlab
classdef REMO_new2_AdaMao_HPC < ALGORITHM
```

这样 PlatEMO 可以将新旧算法作为两个独立算法加载，避免同名类冲突。

### 2.3 允许修改的生产文件

新目录中仅修改：

- `REMO_new2_AdaMao_HPC.m`：修改类名和入口文件名；
- `HybridPBI_Classification.m`：实现新的聚类数、方向去重与补齐逻辑。

其他复制文件保持与源目录一致，除非测试证明存在新入口名称引起的必要引用修改。

## 3. 聚类数设计

### 3.1 新公式

当原有 K-means 启用条件满足时，聚类数设为：

$$
K=\min\left(
N_{ref},
n_{Pareto}-1,
\max\left(M,\left\lceil\sqrt{n_{Pareto}}\right\rceil\right)
\right).
$$

并执行下界保护：

```matlab
K = max(2,K);
```

由于现有自适应分支要求 `nPareto >= max(10,Nref/2)`，正常进入该分支时 `nPareto` 足够支持至少两个簇。

### 3.2 设计含义

- `nPareto-1`：硬性保证聚类数小于样本数，阻止“一点一簇”；
- `M`：保证方向数不会低于目标维数；
- `ceil(sqrt(nPareto))`：样本增加时缓慢增加代表中心数量；
- `Nref`：不超过调用者希望的参考向量总数。

示例：

| M | nPareto | Nref | 原 K | 新 K |
|---:|---:|---:|---:|---:|
| 10 | 70 | 100 | 70 | 10 |
| 10 | 100 | 100 | 100 | 10 |
| 15 | 80 | 100 | 80 | 15 |
| 5 | 25 | 30 | 25 | 5 |

## 4. 自适应中心方向化与去重

K-means 中心仍沿用当前实现流程：

1. 在归一化非支配目标空间聚类；
2. 将中心映射回原始目标空间；
3. 将每一行归一化为单位向量。

本次不改变上述坐标口径，以便把改动严格限制在退化和重复问题。

归一化后执行角度去重。若两个单位向量满足：

$$
1-v_i^Tv_j \leq \varepsilon_{angle},
$$

则认为它们是相同或近重复方向，只保留先出现的方向。

默认使用：

```matlab
angleTol = 1e-10;
```

实现时使用余弦距离或等价的单位向量点积判断，不按原始浮点行值直接 `unique`，避免数值微差掩盖重复方向。

## 5. 无重复的参考向量补齐

### 5.1 候选补充池

若去重后的自适应方向数小于 `Nref`，使用：

```matlab
UniformPoint(Ncandidate,M,'ILD')
```

生成均匀方向候选池，并单位化、角度去重。

`Ncandidate` 应明显大于待补齐数量；初始设计使用：

```matlab
Ncandidate = max(5*Nref, Nref + 100);
```

若 PlatEMO 的 `UniformPoint` 返回数量与请求数量不同，以实际返回数量为准。

### 5.2 最大最小角选择

补齐过程每次选择与已有方向集合最不相似的均匀候选。对候选方向 `u` 定义：

$$
d(u,V)=\min_{v\in V}(1-u^Tv).
$$

每次加入 `d(u,V)` 最大的候选，再更新剩余候选到方向集合的最小余弦距离，直到：

- 参考向量数量达到 `Nref`；或
- 候选池中不再存在与已有方向不同的方向。

这相当于贪心最远角采样：自适应中心负责描述当前前沿，均匀补充方向负责填充当前方向场中的最大角度空洞。

### 5.3 候选池仍不足时

不得重复已有方向。若第一批均匀候选不足，则以更大的 `Ncandidate` 重新生成一次候选池并继续补齐。

若第二次仍无法达到 `Nref`，函数返回现有全部唯一方向，并发出 MATLAB warning，说明有效唯一方向数小于请求数量。不得使用 `repmat` 复制方向。

## 6. 原有回退逻辑

以下情况继续使用原有均匀参考向量路径：

- `M <= 3`；
- `N < 50`；
- `NDSort` 失败；
- `nPareto < max(10,Nref/2)`；
- 任一目标范围小于 `1e-12`；
- K-means 失败或返回空中心。

回退路径也执行单位化和角度去重。若 `UniformPoint` 本身返回近重复方向，则使用同一补齐逻辑保证最终方向尽可能唯一。

## 7. 可测试性设计

为避免测试必须构造 PlatEMO `SOLUTION` 对象，将新的参考方向生成逻辑从 `HybridPBI_Classification.m` 的嵌套函数中提取为新目录内的独立函数：

```text
BuildAdaptiveReferenceVectors_HPC.m
```

建议接口：

```matlab
[V,info] = BuildAdaptiveReferenceVectors_HPC(PopObj,Nref)
```

`info` 至少返回：

- `mode`：`adaptive` 或 `uniform_fallback`；
- `nPareto`；
- `nClusters`；
- `nAdaptiveUnique`；
- `nUniformAdded`；
- `nFinalUnique`；
- `fallbackReason`。

这些诊断信息用于测试和科研日志，不改变混合 PBI 的主要输出接口。

`HybridPBI_Classification.m` 调用该独立函数获得 `V`。

## 8. TDD 验证要求

先建立测试，再编写生产实现。测试至少覆盖：

### 8.1 退化测试

构造 70 个非支配目标向量、`M=10`、`Nref=100`，测试应先在旧逻辑下失败，并在新逻辑下满足：

```text
nClusters < nPareto
nClusters == 10
```

### 8.2 唯一方向测试

最终 `V` 的任意两行余弦距离应大于 `angleTol`，且：

```text
size(V,1) == Nref
info.nFinalUnique == Nref
```

### 8.3 不重复补齐测试

自适应中心少于 `Nref` 时：

```text
info.nUniformAdded > 0
```

并确认补充方向不是自适应中心的重复行。

### 8.4 回退测试

覆盖：

- 非支配解数量不足；
- 某一目标无变化；
- 小规模输入。

测试应确认返回均匀方向、没有重复，并给出正确 `fallbackReason`。

### 8.5 数值性质

每个参考向量满足：

$$
\left|\|v_i\|_2-1\right|<10^{-10}.
$$

不得包含 NaN 或 Inf。

### 8.6 源目录保护

实施前记录源目录全部文件的 SHA-256；实施后重新计算并逐项比较。任何变化均视为测试失败。

### 8.7 新算法入口

静态检查新入口文件名和 `classdef` 名称一致，并确认新目录不存在仍以原主类名定义的 `.m` 入口。

## 9. 验收标准

完成条件：

1. 新目录可以独立作为 PlatEMO 算法目录存在；
2. 源目录 SHA-256 清单前后一致；
3. K-means 聚类数在自适应路径中严格小于非支配样本数；
4. 不再存在复制中心的 `repmat` 补齐逻辑；
5. 正常测试数据下最终返回 `Nref` 个唯一单位方向；
6. 数据不足或异常时安全回退；
7. 所有测试先观察到预期失败，再在实现后通过；
8. 不顺带修改其他 HPC、PBI、坐标归一化或路由机制。

## 10. 非目标

本次明确不包含：

- 将欧氏 K-means 改为 spherical K-means；
- 统一参考向量与理想点的坐标原点；
- 在全局 PBI 中统一目标尺度；
- 混合均匀方向比例的状态自适应；
- 修改混合 PBI 的 `alpha`、confidence 或标签比例；
- 修改候选模式、指标轮盘或环境选择。

这些问题可在该隔离版本验证稳定后分别处理。
