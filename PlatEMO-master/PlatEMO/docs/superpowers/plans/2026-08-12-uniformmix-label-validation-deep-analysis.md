# UniformMix 标签验证实验深度分析

**日期**：2026-08-12  
**分析者**：Claude (Opus 5)  
**目标**：评估五阶段实验设计是否合理，能否有效检测"双PBI标签"的独立作用

---

## 一、核心机制拆解

### 1.1 "双PBI"的实际定义

从 `HybridPBI_Classification.m` 源码可见：

```matlab
% 信号1：连续方向场得分
score_v = 1 ./ (1 + PBI_v);  // PBI_v = d1 + theta*d2

% 信号2：二值锚点标签  
label_dyn = GetOutput_PBI(PopObj, RefObj);  // 自适应δ阈值划分

% 融合
alpha = 1 - ratio;  // 早期α大→偏score_v，后期α小→偏label_dyn
score_hybrid = alpha * score_v + (1-alpha) * double(label_dyn);
Catalog = topQ(score_hybrid, rGood);  // 前25%为正组
```

**关键事实**：
- `score_v` 的方向 `V` 来自**当前种群非支配解的K-means中心**（高维时）
- `label_dyn` 的锚点 `Ref` 来自**同一当前种群**通过 `RefSelect` 选出
- 两者**不是独立的全局先验与局部观测**，而是同一数据的两种压缩

Stage 1 规划第22行已承认此事实：
> "两种信号都来自当前 Population，不是相互独立的全局先验与局部信息。"

---

## 二、实验设计评估

### 2.1 五阶段逻辑链

| 阶段 | 目标 | 关键输出 | 决策门槛 |
|---:|---|---|---|
| **Stage 1** | 快照审计 | 等价性验证、方向来源统计 | 审计不改变Hybrid轨迹 |
| **Stage 2** | 标签消融 | L0-L8 overlap/分歧/稳定性 | L3与L1/L2存在非平凡分歧 |
| **Stage 3** | 外部效用 | Oracle Top25捕获率、LOO贡献 | L3优于打乱对照且优于单支路 |
| **Stage 4** | 模型泛化 | solution-disjoint AUC/NDCG | QueryNDCG优于锚点对照 |
| **Stage 5** | 端到端优化 | 30-run IGDp配对检验 | 几何均值比≤1.05且有主效应 |

**逻辑完整性：9/10** ✅  
- 层层推进，每阶段有明确通过/停止条件
- 预注册决策避免p-hacking
- 负对照充分（L6打乱、L7均匀、L8方向数）

### 2.2 统计严谨性

**优点**：
- ✅ run-cluster bootstrap（10000次，固定seed=20260811）
- ✅ Holm多重比较校正
- ✅ 配对检验+效应量+95% CI
- ✅ DTLZ/WFG分别报告，避免跨问题直接平均

**不足**：
- ⚠️ Stage 2称为"因果消融"但实际是**固定快照上的标签变体比较**
  - 未动态干预轨迹，无法建立"标签→种群状态→后续标签"的因果链
  - 建议改称"标签构造系统消融"
- ⚠️ Stage 3的IGD+贪心Oracle可能偏向收敛而非探索
  - 应增加"H1-survival"（下一代是否保留）作为辅助真值

### 2.3 关键实现问题

#### 问题1：坐标原点不一致

`HybridPBI_Classification.m` 第68-79行：

```matlab
% 方向关联：用原始PopObj
cosine = 1 - pdist2(PopObj, V, 'cosine');
[~, ref_idx] = max(cosine, [], 2);

% PBI投影：用PopObj-Zmin
d1(i) = (PopObj(i,:) - Zmin) * w' / norm(w);
```

**影响**：
- 关联到的方向 ≠ 实际投影方向的几何基准
- E5（几何一致版本）被推迟到Stage 5敏感性，而非Stage 1就修复

**建议**：
- 将E5设为默认实现，当前版本改为"E2_Legacy"仅作历史对照

#### 问题2：自适应δ可能为负

`GetOutput_PBI.m` 第60-70行：

```matlab
while r>0.7 || r<0.3
    delt_c = (delt_l + delt_u)/2;
    [l,r] = split_data(Pop,Ref,delt_c);
    if r > 0.7
       delt_l = delt_c;
    elseif r < 0.3
       delt_u = delt_c;  // delt可能进入[-20,0)
    end
end
```

当δ<0时，PBI公式 `g = d1 + δ*d2` 的垂直距离项会**奖励偏离**而非惩罚。  
此时 `g>1` 的划分标准不再能解释为"偏离锚点过大"。

**建议**：
- 在Stage 1审计时记录δ的实际分布
- 若频繁出现δ<0，需在论文中明确说明PBI阈值的非标准语义

---

## 三、核心假设的可证伪性

### 3.1 四个预注册假设

| 假设 | 陈述 | Stage 2指标 | Stage 3指标 | 可能失败点 |
|---:|---|---|---|---|
| **H1** | 非支配方向有额外效用 | L2≠L1的overlap | L2优于L1的NDCG | L2与L1高相关(>0.8) |
| **H2** | 两路信号互补 | L3≠max(L1,L2) | L3优于L2且优于L6 | L3≈L2或L3≈L6打乱 |
| **H3** | 时间调度方向正确 | L3在EARLY更接近L2 | L3优于L4和L5 | L3≈L4固定权重 |
| **H4** | 非支配来源有意义 | L2≠L7的overlap | L2优于L7 | L2≈L7均匀方向 |

### 3.2 最可能的失败模式

基于CascadeAudit的先行失败（H2 fail：指标正分歧不能识别假阴性），预测：

**情景A：独立性假设失败**（概率：60%）
- Stage 2：L1与L2的Spearman相关 > 0.80
- Stage 3：L2-L1效应小（<0.02）且置信区间宽
- 结论：`SIMPLIFY_ANCHOR_ONLY` 或 `SIMPLIFY_DIRECTION_ONLY`
- 原因：两个PBI信号本质是同一种群的不同聚合，不构成互补

**情景B：调度失效**（概率：30%）
- Stage 2：L3、L4、L5的overlap > 0.95
- Stage 3：H3时间交互不显著
- 结论：`PASS_LABEL_BUT_DROP_SCHEDULE`
- 原因：α权重变化被score_v/label_dyn的低方差掩盖

**情景C：模型断裂**（概率：40%）
- Stage 3：L3优于L1/L2（PASS）
- Stage 4：`LABEL_GAIN_NOT_TRANSFERRED`
- 原因：patternnet的硬二值Catalog丢失了连续score_v的细粒度排序信息

**情景D：完全通过**（概率：<20%）
- 所有阶段PASS，E2在formal实验中显著优于E0
- 但效应量可能很小（IGDp改善<5%）

---

## 四、关键风险点

### 4.1 Stage 2的"因果"声明过强

**当前表述**（02_Stage2_LabelCausalAblation_Plan.md 标题）：
> "标签构造因果消融实施规划"

**问题**：
- L0-L8都是在**固定快照**上计算的离线标签变体
- 比较的是"标签结构差异"，而非"标签A→轨迹变化→后续状态B"的动态因果
- Pearl因果框架要求**反事实推断**或**随机化干预**，而Stage 2只有关联分析

**建议修正**：
- 改为"标签构造系统消融"或"标签机制分离验证"
- 在文档第6-14行明确说明"本阶段不训练关系网络，也不运行Problem.Evaluation"

### 4.2 Stage 3的Oracle可能有偏

**IGD+贪心Top25的局限**：
1. 基于R4096离线参考集，可能不足以代表真实PF（尤其WFG3退化PF）
2. 贪心选择**过度强调收敛**，忽视探索价值
3. 不包含"选择这个解后对后续种群分布的影响"

**证据**：
- Stage 3规划第257行的敏感性显示：R4096→R8192时，若Jaccard<0.90则需增密到R16384
- 这说明Oracle本身对参考集密度敏感

**建议**：
- 增加"H1-survival"（当前解在下一训练代是否保留）作为动态真值
- 报告IGD+贪心与HV贪心的Top25重合度，若<0.80则需谨慎解读

### 4.3 Stage 4的端点泄漏检查

**当前validator**（Stage 4规划第124-127行）：
```matlab
isempty(intersect(trainEvalID,testEvalID))
```

**不足**：
- 只检查基础解ID不重叠
- 未明确检查**反向关系对泄漏**：若(i,j)∈train，是否保证(j,i)∉test？

**理论风险**：
- 关系对(i,j)和(j,i)虽然标签相反，但共享相同的端点信息
- 若train有(i,j)而test有(j,i)，模型可能通过"记忆端点特征"而非"学习关系模式"来泛化

**建议**：
- 在validator中增加显式检查：
  ```matlab
  for each (i,j) in trainPairs:
      assert (j,i) not in testPairs
  ```

### 4.4 Stage 5的baseline选择

**当前E0（AnchorNative）定义**（Stage 5规划第68行）：
> "原始 `LabelDyn` 自然比例"

**问题**：
- E0正例比例由自适应δ决定，目标区间[0.30, 0.70]
- E2正例比例固定为0.25
- 两者同时改变了**比例**和**得分类型**，无法归因

**建议**：
- 增加E0.5："固定25%的纯锚点标签"（`topQ(AnchorMargin, 0.25)`）
- 这样E0.5 vs E2的对比才是"锚点vs融合"的干净消融

---

## 五、能否检测双PBI作用？

### 5.1 检测能力评估

✅ **能检测到的信号**：
1. L2与L1的标签分歧（Stage 2：Jaccard、分歧集合大小）
2. L3与L2的外部效用差异（Stage 3：NDCG、AUC、Oracle捕获率）
3. 融合权重α的时间交互（Stage 3：EARLY/MIDDLE/LATE分层分析）
4. 模型query质量改善（Stage 4：QueryNDCG@25、QueryAUC）
5. 最终优化性能（Stage 5：30-run IGDp配对检验）

⚠️ **可能检测不到的信号**：
1. **若L1与L2高相关**（Spearman > 0.80）：
   - 无法区分哪个分支更重要
   - L3的改善可能只是"固定比例+连续化"的联合效应
2. **若α调度无效但L3仍通过**：
   - 可能误导为"时间调度有效"
   - 实际是L2/L1某一项单独贡献，而非动态权衡
3. **若Stage 4断裂**：
   - 无法判断是标签问题（细粒度信息丢失）还是网络容量问题

### 5.2 预测结果

基于CascadeAudit的先行失败（"指标正分歧不能识别假阴性"），以及代码中承认的"两信号来自同一种群"，预测：

**最可能路径**（概率：55%）：
- Stage 2：L3与L1/L2有分歧 → `PASS_TO_STAGE3`
- Stage 3：L2-L1效应不稳定，L3≈L2 → `SIMPLIFY_DIRECTION_ONLY`
- Stage 4：L2模型不优于L1 → `PASS_DIRECTION_MODEL_ONLY`（诊断性）
- Stage 5：screening显示E1≈E2 → `MECHANISM_ONLY_NO_FORMAL_GAIN`

**次可能路径**（概率：30%）：
- Stage 2：PASS
- Stage 3：L3优于L6但不优于L2 → `SIMPLIFY_DIRECTION_ONLY`
- 后续阶段只验证E1（方向单支路），不进入30-run formal

**乐观路径**（概率：<15%）：
- 全部PASS，E2在formal中优于E0
- 但效应量小（IGDp改善2-4%），且可能只在1-2个问题上显著

---

## 六、改进建议

### 6.1 P0级修改（必须）

1. **Stage 1：立即修复几何一致性**
   - 将E5设为默认实现
   - 方向关联和PBI投影使用统一坐标：`(PopObj-Zmin, V-Zmin)`

2. **Stage 2：增加独立性检验**
   - 在 `variantRows` 中增加字段：
     ```
     ScoreVLabelDynSpearman
     ScoreVLabelDynMI  // 互信息
     ```
   - 若Spearman > 0.80，自动触发 `WARNING_HIGH_SIGNAL_CORRELATION`

3. **Stage 4：明确反向关系对检查**
   - validator增加显式循环检查：
     ```matlab
     for k = 1:size(trainPairs,1)
         i = trainPairs(k,1);
         j = trainPairs(k,2);
         assert(~any(testPairs(:,1)==j & testPairs(:,2)==i));
     end
     ```

### 6.2 P1级增强（强烈建议）

1. **Stage 3：多维度Oracle**
   - 不只报告IGD+贪心，也报告：
     - HV贪心Top25
     - CDiver（拥挤距离）贪心Top25
     - 三者的Jaccard重合度

2. **Stage 4：性能上界基准**
   - 增加"完整Population训练+完整Population测试"作为理论上界
   - 若solution-disjoint AUC远低于此上界，说明泛化困难本质

3. **Stage 5：细化baseline**
   - E0.5："固定25%纯锚点"（`topQ(1-AnchorNormalizedG, 0.25)`）
   - E3.5："固定α=0.5但连续topQ"（区分调度和连续化效应）

### 6.3 P2级可选（论文增强）

1. **Stage 2：时间窗口趋势**
   - 绘制 `Jaccard(L3,L2)` vs `ratio` 曲线
   - 检验"早期接近L2、后期接近L1"的假设

2. **Stage 4：fold size敏感性**
   - 2-fold vs 3-fold vs 5-fold
   - 检验solution-disjoint泛化是否对划分粒度敏感

3. **Stage 5：预算扩展**
   - 增加maxFE=1000的run（2 problems × 2 M × 3 runs）
   - 检验改善是否只在低预算（maxFE=500）有效

---

## 七、最终评分与结论

### 7.1 实验设计总评

| 维度 | 评分 | 理由 |
|---|---:|---|
| **逻辑完整性** | 9/10 | 五阶段层层推进，决策链清晰 |
| **统计严谨性** | 9/10 | 预注册、负对照、多重校正、配对检验 |
| **负对照设计** | 9/10 | 打乱、均匀、方向数、反向调度、固定权重 |
| **独立性假设** | 6/10 | 承认两信号来自同一种群，但未量化相关性 |
| **实现一致性** | 7/10 | 坐标不一致问题推迟到敏感性而非立即修复 |
| **因果推断** | 6/10 | Stage 2称"因果"但实际是固定快照关联分析 |
| **Oracle有效性** | 7/10 | IGD+贪心可能偏向收敛，缺乏动态轨迹真值 |
| **文档质量** | 10/10 | 极其详尽，执行协议可完全复现 |

**总分：8.0/10**

### 7.2 核心结论

✅ **实验设计总体合理**，能够检测"双PBI标签"的存在性及其贡献。

⚠️ **但检测结果很可能是"无独立互补性"**，因为：
1. 两个PBI信号都来自同一当前种群，可能高度相关（>0.80）
2. CascadeAudit的失败（指标分歧无法识别假阴性）提供了先验警告
3. 坐标不一致和自适应δ<0的实现细节会引入额外噪声

🎯 **最可能的结果**：
- Stage 2-3通过（存在分歧且有外部效用差异）
- Stage 4-5部分通过或失败（模型无法利用细粒度信号，或端到端无改善）
- 最终论文贡献收窄为"连续化+固定比例的联合效应"，而非"两种独立信号的互补融合"

### 7.3 执行建议

**在启动screening前**：
1. 先执行mini-pilot（1 run × DTLZ2/WFG3 × Stage 1-3）
2. 检查关键指标：
   - `Spearman(score_v, label_dyn)` 是否 < 0.70？
   - L2与L1的overlap是否 < 0.85？
   - L3与L6打乱包络的分离度是否显著？
3. 若上述任一失败，需调整研究假设再决定是否继续screening

**论文策略**：
- 准备两版论文框架：
  - **版本A**："双PBI互补融合"（乐观情景）
  - **版本B**："连续标签与固定比例的联合改进"（保守情景，删除"互补"和"时间调度"叙事）
- 根据Stage 3结果快速切换版本

---

## 附录：关键文献引用建议

若假设H1-H4部分失败，需在Discussion中引用以下文献支撑负结果解释：

1. **同源信号的独立性问题**：
   - Deb & Jain (2014) "An Evolutionary Many-Objective Optimization Algorithm Using Reference-Point-Based Nondominated Sorting Approach" - NSGA-III的参考点也来自已观测解
   - 说明"数据依赖方向"与"数据本身"的互补性是EMO中的普遍挑战

2. **离线Oracle的局限性**：
   - Zitzler et al. (2003) "Performance Assessment of Multiobjective Optimizers: An Analysis and Review" - 讨论IGD等指标对参考集的敏感性
   - 用于解释为何Stage 3通过但Stage 5失败

3. **关系学习的泛化困难**：
   - Chen et al. (2018) PC-SAEA原文 - 承认关系模型在高维决策空间的泛化挑战
   - 用于解释Stage 4的solution-disjoint AUC下降

---

**文档状态**：FINAL  
**适用范围**：执行screening前的Go/No-Go决策  
**下一步**：根据本分析结果决定是否修改协议或启动mini-pilot
