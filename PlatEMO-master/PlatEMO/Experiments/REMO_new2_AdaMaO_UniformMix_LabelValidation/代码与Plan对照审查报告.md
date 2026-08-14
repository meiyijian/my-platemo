# 实验代码 vs Plan 文件 对照审查报告

**审查范围**：`PlatEMO/Experiments/REMO_new2_AdaMaO_UniformMix_LabelValidation/`
**对照基准**：同目录下 5 个 Stage Plan（01–05）及 `PlatEMO/docs/superpowers/plans/2026-08-12-uniformmix-label-validation-deep-analysis.md`
**审查日期**：2026-08-13
**结论**：Stage 1–3 已实现且大体忠实于 plan；Stage 4/5 尚未实现。但存在若干**明确违反 plan 要求**的实现问题，主要集中在 Stage 3。

---

## 一、严重问题（bug / 明确违反 plan）

### S1. Stage 3「有效非并列对」判定实现错误
- **文件**：`ComputeExternalLabelMetrics.m` 第 38 行
  ```matlab
  nNonTie = nnz(U ~= U(1));
  insufficient = (nNonTie < 10);
  ```
- **plan 要求**（Stage 3 §5.2 / Task 4）："有效非并列对不足 10 时，把 Kendall/AUC/NDCG 标记为 NaN 并记录 INSUFFICIENT_UTILITY_VARIATION"。
- **问题**：`nnz(U ~= U(1))` 统计的是「与第一个元素不同」的元素个数，不是「非并列对数」（应为所有 pairs 中 `U(i)~=U(j)` 的对数）。当 `U(1)` 恰为极值时，该值会严重偏离真实非并列对数，导致 INSUFFICIENT_UTILITY_VARIATION 误判。

### S2. Stage 3 Holm 多重比较校正未实现
- **文件**：`analyze_IndependentUtilityValidation.m` 第 320 行
  ```matlab
  hpv = pv;   % placeholder; Holm applied in computeDecision
  ```
- **plan 要求**（Stage 3 §9 Task 5）："同一指标的多版本比较使用 Holm 校正，报告原始 p、校正 p、配对效应和 95% CI"。
- **问题**：Holm 校正是占位符，且 `computeDecision` 中也从未使用任何校正 p 值。

### S3. Stage 3 决策逻辑未纳入效应量与置信区间
- **文件**：`analyze_IndependentUtilityValidation.m` `computeDecision()`（第 434–478 行）
- **plan 要求**（Stage 3 §10）："Stage 3 的『通过』必须同时包含效应量和置信区间，不允许仅以未校正 p<0.05 决定"。
- **问题**：决策仅用 `median(delta)` 的符号判断（如 `dL2L1 > 0`），未使用 bootstrap 的 95% CI 或校正 p 值。

### S4. Stage 3 的 Stage-2 gate 允许列表错误
- **文件**：`run_IndependentUtilityValidation.m` 第 60–62 行
  ```matlab
  allowedDecisions = {'PASS_TO_STAGE3','PASS_LABEL_COMPLEMENTARITY', ...
      'SIMPLIFY_DIRECTION_ONLY','SIMPLIFY_ANCHOR_ONLY', ...
      'PASS_LABEL_BUT_DROP_SCHEDULE'};
  ```
- **plan 要求**（Stage 3 §2）："Stage 2 的唯一主决策是 `PASS_TO_STAGE3`；`SCHEDULE_REDUNDANT`/`DIRECTION_SOURCE_REDUNDANT` 只作为 WarningFlags 传入分层分析"。
- **问题**：后 4 个是 **Stage 3 自己的决策代码**，永远不会出现在 `Stage2_decision.csv` 中，属于概念混淆；同时未实现「WarningFlags 传入分层分析」。

### S5. 检查点（checkpoint）选择偏离 plan，且存在索引错位 bug
- **文件**：`run_IndependentUtilityValidation.m` `chooseCheckpoints()`（第 350–373 行）+ 第 251 行
- **plan 要求**（Stage 3 §3）："若两个 target 映射到同一 snapshot，仅保留较早的 target，并把另一个标记为 `UNAVAILABLE_CHECKPOINT`，不得复制同一快照充数"。
- **问题**：
  1. 代码用 `used` 标记后**退而求其次选次近 snapshot**，而非标记 `UNAVAILABLE_CHECKPOINT`；
  2. 一旦某个 target 无可用 snapshot（记 NaN 后被 `idx(~isnan(idx))` 丢弃），第 251 行的 `TargetRatio = targetRatios(c)` 会因 `c` 与原始 target 下标错位而**标错 TargetRatio**。

### S6. 参考集构建方式与 plan §4.1 不符
- **文件**：`BuildLabelUtilityReferenceSet.m` 第 84 行
  ```matlab
  Rmaster = Problem.GetOptimum(16384);
  R4096 = Rmaster(1:4096,:); R8192 = Rmaster(1:8192,:);
  ```
- **plan 要求**（Stage 3 §4.1）：非 DTLZ7 问题应 `R4096 = Problem.GetOptimum(4096); R8192 = Problem.GetOptimum(8192);`（DTLZ7 才用 16384 前缀构造）。
- **问题**：代码把所有问题统一改为 `GetOptimum(16384)` 取嵌套前缀。`GetOptimum(4096)` 与 `GetOptimum(16384)` 的前 4096 行通常**不是同一批点**，导致 R4096/R8192 与 plan 规定不同。
- **实锤**：当前 `stage3/screening` 已产出 `INSUFFICIENT_REFERENCE_STABILITY`（`DTLZ7_M10` 升级到 R16384 后仍未通过）。

---

## 二、中等偏离 / 简化

### M1. Stage 3 的 L6 打乱标签未计算排名类指标
- **文件**：`ComputeExternalLabelMetrics.m` 第 83–90 行
- **plan 要求**（Stage 3 §6.1）：L1–L8 统一计算 `PrecisionAt25/RecallAt25/JaccardAt25/NDCGAt25_LOO/KendallTauB_LOO/PairwiseAUC_LOO/…`。
- **问题**：代码对 L6 跳过 NDCG/Kendall/AUC，仅保留 set 类指标。工程上合理，但严格偏离 plan 字段契约。

### M2. H2 打乱检验门槛过宽松
- **文件**：`analyze_IndependentUtilityValidation.m` 第 444、450 行
  ```matlab
  l3AboveShuffle = ~isempty(shufPct) && median(shufPct) > 0.50;
  ```
- **plan 暗示**（Stage 3 §6.2 / §11）：L3 应「持续高于打乱分布 / 位于高分位」。
- **问题**：`> 0.50` 仅要求过半，远低于 plan 暗示的「高分位」门槛。

### M3. Stage 3 配对与 source-hash 校验不完整
- **文件**：`run_IndependentUtilityValidation.m` 第 186–190 行
- **plan 要求**（Stage 3 §2）：两阶段 `pairedKey/behavior/problem/M/run/seed` 完全相同；Stage 2 source hash 对应当前 Stage 1 文件。
- **问题**：仅核对 `pairedKey/M/run`，漏掉 `behavior/problem/seed`；`stage1MetadataHash` 与 `stage2MetadataHash` 仅写入未做一致性校验。

### M4. Stage 1 runner 缺前置 which 检查
- **文件**：`run_LabelMechanismSnapshotAudit.m`
- **plan 要求**（Stage 1 Task 1）：前置检查五个问题、冻结算法、`kmeans/pdist2/fitrsvm/patternnet` 均非空，并验证 `which('REMO_new2_AdaMaO_SDEOnly_UniformMix_Original')` 解析到独立算法目录。
- **问题**：runner 未实现；仅 `tests/test_LabelMechanismSnapshotAudit.m` 覆盖了 WFG3 D 维度检查（部分）。

### M5. Stage 2 INSUFFICIENT_DATA 统计粒度不一致
- **文件**：`analyze_LabelCausalAblation.m` 第 380–394 行（按 problem 粒度）；对比 Stage 1 analyzer（按 problem×M 粒度）
- **plan 表述**：「任一问题家族少于 4 个有效 paired run」。代码按「问题」粒度且不区分 M，与 Stage 1 的 problem×M 粒度不一致，语义上偏宽松。

### M6. Stage 2 overlap「对称性」检查退化
- **文件**：`ComputeLabelOverlapMetrics.m` 第 24–25 行（只生成 `i<j` 无序对）
- **plan 要求**（Stage 2 Task 4）："检查 overlap 对称性：`Jaccard(A,B)==Jaccard(B,A)`"。
- **问题**：只生成无序对导致「对称性检查」名存实亡（无重复行可查）。

---

## 三、轻微问题

1. **L7 的 DirectionSource 标记语义不符**（`ComputeLabelAblationVariants.m` 第 127 行）：L7 主动用均匀方向，却标记为 `2 = UNIFORM_LOW_M_OR_N`（该枚举本意是 M≤3 或 N<50 触发）。
2. **L0 仍生成 ranking**（`ComputeLabelAblationVariants.m` 第 44 行）：plan §4.2 明确「不得伪造二值标签内部排名」，代码仍用 `sortrows` 为 L0 生成 ranking（虽 overlap 中 Spearman 已置 NaN）。
3. **Stability 的 L8 重复计算**（`ComputeLabelPerturbationStability.m` 第 73–88 行）：对同一 retainIdx 调用了两次 `ComputeReducedNDDirectionScore`（一次取 score、一次取 dsAfter），第二次是冗余重算。
4. **Stage 1 `finalPopulation` 顶层变量语义**（`LVUniformMixAuditBase.m` 第 244 行）：保存的是完整 `Archive`（所有评价解），而 plan §6 仅写「finalPopulation」，未明说是最终 Population 还是 Archive；与 `IGD/IGDp`（基于 `result{end,2}`）口径需确认一致。

---

## 四、结构性问题

1. **Stage 4 / Stage 5 完全未实现**：plan 04/05 要求的 `run_RelationModelGeneralization.m`、`run_LabelEndToEndExperiment.m`、`algorithms/end_to_end/*` 等均不存在。这符合「按序推进」的计划，但需知悉当前仅覆盖 Stage 1–3。
2. **深度分析文档 P0 建议未落实**：
   - P0-1「Stage 1 立即修复几何一致性（E5 默认化）」——未落实（但 Stage 1 plan 明确要求「本阶段不修复几何公式」，故此项**符合 Stage plan、仅与深度分析建议相左**）；
   - P0-2「Stage 2 variantRows 增加独立性检验字段（ScoreVLabelDynSpearman / ScoreVLabelDynMI）」——未落实；
   - P0-3「Stage 4 反向关系对泄漏显式检查」——Stage 4 尚未实现。

---

## 五、已正确对齐的部分（摘要）

- Stage 1 种子公式（`problemIndex*10000 + M*100 + run`）、七参数、问题矩阵、WFG3 actualD=31、DirectionSource 枚举、快照/评估/轨迹字段、等价性测试（smoke + pilot 双等价性，已生成 `equivalence_passed.txt`）均正确。
- Stage 2 L0–L8 变体定义、`LVTopQDeterministic` 行序并列规则、offlineSeed 公式、L3 复现校验（`STOP_REPRODUCTION_FAILURE`）、StageBin、决策优先级、WarningFlags 均正确。
- Stage 3 `LVIGDPlus`、贪心 Oracle（EvalID 并列）、留一 LOO、未来 H1/H3/FINAL 重建、归一化公式、DTLZ7 专用构造公式均正确。
