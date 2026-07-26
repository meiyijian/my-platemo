# AdaMaO Confidence 判别能力探针实验设计

日期：2026-07-26
状态：用户已批准方案 A，允许直接在主分支实现
Git 根目录：`D:\PlatEMO-master`
PlatEMO 根目录：`D:\PlatEMO-master\PlatEMO-master\PlatEMO`

## 1. 研究问题

本实验只验证 confidence 是否具有判别意义，不比较关系对模式优劣，也不据此直接声称 IGD 改善。

主研究对象是 `HybridPBI_Classification` 返回的 PBI 双表征一致性：

\[
c_i=1-\left|score_{v,i}-label_{dyn,i}\right|.
\]

现有 weighted 关系对的置信度定义保持不变：

\[
c_{ij}=\sqrt{c_i c_j}.
\]

它不是好解分数，也不是校准概率。当 `label_dyn=1` 时，高值表示“较确定地判好”；当
`label_dyn=0` 时，高值表示“较确定地判为非好”。因此实验不能预设所有高 confidence
解都有更高存活率或改进率。

源码中的第二种量 `max(pre_out)` 是关系网络 softmax 尖锐度。本实验将其明确命名为
`NetworkConfidence`，仅用于未见候选的时间外诊断，不与 `PBIConfidence` 合并。

## 2. 可证伪假设

### 2.1 PBI confidence 主假设

在已真实评估的当前种群中，对 `Catalog` 判为好解与非好解的跨组关系对：

- H1：`PBIConfidence` 越高，针对严格 Pareto 可比较关系的方向错误率越低；
- H2：`PBIConfidence` 越高，针对真实 SDE 排序的方向一致率越高；
- H3a：在判好解组内，confidence 越高，未来活动种群存活率和最终第一前沿率越高；
- H3b：在判为非好解组内，confidence 越高，未来活动种群存活率和最终第一前沿率越低，
  或至少不出现显著的反向证据。

### 2.2 网络 confidence 辅助假设

关系网络在第 t 代训练完成后，对最终选中但尚未真实评估的候选与当前锚点进行前向预测。
候选在随后正常的 `Problem.Evaluation` 中取得真实目标：

- H4：`NetworkConfidence` 越高，候选—锚点的 Pareto/SDE 关系预测错误越低；
- H5：在网络判候选更好时，confidence 越高，候选的真实改进率和下一代存活率越高；
- H6：在网络判候选更差时，confidence 越高，真实拒绝正确率越高。

H4–H6 只支持网络 confidence，不作为 PBI confidence 的证据。

## 3. 禁止作为真值的量

以下量均与 PBI confidence 同源或存在端点泄漏，不作为实验真值：

- `Catalog`；
- 由 `Catalog` 生成的 `YYs`；
- 现有 `p_err`；
- 按关系对行随机拆分得到的内部 test error；
- “进入 Archive”。

现有 `Archive` 会无条件追加每个 `NewSols`，因此进入率恒为 100%。后续保留必须定义为：

- 下一次 `RefSelect` 后仍在活动 `Population`；
- 三次环境选择后仍在活动 `Population`；
- 当前历史真实评估集合的第一非支配前沿；
- 最终历史真实评估集合的第一非支配前沿。

## 4. 真值定义

### 4.1 严格 Pareto 关系

先比较总约束违反量；约束违反量更小者更好。两者均可行时，按最小化问题的严格 Pareto
支配定义 `+1/-1/0`：

- `+1`：左端严格支配右端；
- `-1`：右端严格支配左端；
- `0`：不可比或数值相等。

Pareto 方向错误率只在真值非 0 的可比较关系对上计算。不可比关系不会被当成“预测正确的
同组关系”，避免 many-objective 场景中的 0 类膨胀。

### 4.2 真实 SDE 排序

在同一个真实目标集合上调用现有 `calFitness_SDE`，得分越大越好。两个得分差异低于数值
容差时记为 0，否则给出 `+1/-1`。SDE 是真实目标上的集合依赖排序代理，不称为 Pareto 真值。

### 4.3 候选真实改进

仅使用算法正常选中并由 `Problem.Evaluation` 消耗 FE 的候选，记录：

- `DominatesAny`：是否支配至少一个第 t 代活动解；
- `DominatedByAny`：是否被至少一个第 t 代活动解支配；
- `IsNondominated`：加入第 t 代活动解后是否非支配；
- `MarginalIGD`：单独加入候选后，相对第 t 代活动种群的 IGD 减少量；
- `MarginalIGDPositive`：减少量是否大于数值容差；
- `SurviveH1/SurviveH3`；
- `ArchiveNDNext/FinalND`。

不免费评价未选候选，不改变 FE 口径。

## 5. 数据采集架构

新增一个与 `UniformMix` 平行的探针算法：

`REMO_new2_AdaMaO_SDEOnly_ConfidenceProbe`

它复制 `REMO_new2_AdaMaO_SDEOnly_ModeBase` 的运行链，并固定 candidate policy 为
`uniform_mix`。原始基准及共享函数不修改。

每次真实评价时通过 `SOLUTION.add` 写入唯一 `EvalID`：

- 初始解 ID 为 `1:N`；
- 新解 ID 为评价前 `Problem.FE + (1:n)`；
- 主键为 `(Problem, M, Run, EvalID)`。

探针输出四张原始数值表：

1. `solutionRows`：当前已评估解的 Catalog、PBI confidence、SDE、前沿和未来存活；
2. `pbiPairRows`：已评估解之间的 PBI pair confidence、Pareto/SDE 真值和未来关系；
3. `networkPairRows`：评价前候选—锚点网络概率，评价后补真实关系；
4. `candidateRows`：真实候选改进和存活结果。

原始表保存在每个 run 的 MAT 文件中。分析脚本只输出可管理的分箱与汇总 CSV，不输出数 GB
的全量关系对 CSV。

## 6. 非扰动约束

- 不额外调用 `HybridPBI_Classification`，避免高维 k-means 推进全局随机数；
- PBI 诊断对使用确定性枚举和等距抽样，不调用 `rand/randperm`；
- 网络前向预测是无状态只读计算；
- SDE、Pareto、IGD 诊断不调用 `Problem.Evaluation`；
- 原 `CreateSDECandidateModeStream` 每代一次 draw 的位置保持不变；
- 训练关系对、神经网络训练和候选生成的随机调用顺序保持不变；
- 使用相同 seed 时，探针与原 `UniformMix` 的最终决策值、目标值、FE 必须一致。

每代最多保存 900 个 PBI 诊断对：good-good、rest-rest、good-rest 三类各最多 300 个，并在
每类 confidence 排序后确定性等距抽取，既限制文件大小又保留完整 confidence 范围。

## 7. 分箱与统计单位

- PBI 对：在 `Problem × M × Run × Generation × PairType` 内分 confidence 五等频组；
- 解：在 `Problem × M × Run × Generation × Catalog` 内分五等频组；
- 网络候选对：在 `Problem × M × Run × Generation × PredictedRelation` 内分五等频组；
- 候选：在 `Problem × M × Run × Phase` 内按聚合 NetworkConfidence 分五组；
- early/middle/late phase 按 FE 进度三等分；
- 有向反向对和共享端点不当作独立重复；
- 首先形成每个 run 的分箱率，再形成问题级汇总；
- M=10 与 M=20 始终分开；
- 跨问题汇总对问题等权，使用“问题 → 问题内 run”的分层 Bootstrap。

## 8. 预先冻结的判断门槛

PBI confidence 存在判别意义需要同时满足：

1. 跨组关系对 Q5−Q1 Pareto 方向错误率差的 95% 分层 Bootstrap 上界小于 0；
2. confidence 判别正确/错误的 AUROC，其 95% CI 下界大于 0.5；
3. 至少 4/5 个问题的 Q5−Q1 错误率方向小于 0。

达到以上条件但绝对错误率下降不足 0.05，只称为“存在弱判别信息”；达到至少 0.05 且下游
条件关系不反向，才称为“具有门控开发价值”。

如果主判据失败，不应继续用 `mean_conf>=0.55` 设计门控。若主判据通过但存活/改进不支持，
confidence 只能作为标签可靠性诊断，不能宣称改善搜索。

## 9. 实验配置

提供四个 profile：

- `smoke`：DTLZ2，M=3，D=3，N=20，maxFE=36，run=1，`gmax=1`；
- `pilot`：DTLZ2/DTLZ7/WFG3，M=10，maxFE=500，3 个固定种子；
- `screening`：DTLZ2/DTLZ4/DTLZ7/WFG3/WFG7，M=10，maxFE=500，10 个固定种子；
- `confirmation`：同五问题，M=20，maxFE=500，10 个固定种子。

WFG3 的实际 D=31，其余请求 D=30。只有 M=10 screening 达到主门槛后才运行 confirmation。

## 10. 输出

每次运行生成一个原子写入的 `run_XXX.mat`，包含：

- `metadata`；
- `confidenceProbe`；
- `finalPopulation`；
- `IGD`、`IGDp`；
- `runtime`。

分析后生成：

- `Confidence_PBI_pair_bins.csv`；
- `Confidence_PBI_solution_bins.csv`；
- `Confidence_network_pair_bins.csv`；
- `Confidence_candidate_bins.csv`；
- `Confidence_summary_by_problem.csv`；
- `Confidence_summary_by_M.csv`；
- `Confidence_decision.csv`；
- `Confidence_analysis.mat`。

## 11. 冻结的基准文件

下列 Git blob 必须保持不变：

| 文件 | Git blob |
|---|---|
| `REMO_new2_AdaMaO_SDEOnly_UniformMix.m` | `523deb264424909d84334bdeacf81377352eca8a` |
| `REMO_new2_AdaMaO_SDEOnly_ModeBase.m` | `411a828ae68111e4ede67709386832624d4c38a4` |
| `private/HybridPBI_Classification.m` | `342658c826e2f1f96937f1d300896b14331d2e2d` |
| `private/GetOutput_PBI.m` | `de30b2e915908e6d205134168a0cf87894a97cb9` |
| `private/AdaMaOSelection.m` | `b2483d050e91586356871d56e4bbb6ca4cc0aabd` |
| `private/RefSelect.m` | `241e8940b34b1c1c8cdc092d1db3cecf9407bb86` |

## 12. 验收条件

- helper 单元测试覆盖真值、pair confidence、确定性抽样、分箱、未来存活和候选改进；
- 测试先失败，再实现通过；
- smoke 至少产生一次初始化后的完整探针记录；
- 同 seed 的原 UniformMix 与 ConfidenceProbe 轨迹一致；
- 已有 SDEOnly 回归测试继续通过；
- 新增 MATLAB 文件 `checkcode` 无问题；
- 结果 validator 能拒绝缺字段、不完整或元数据不匹配的 MAT；
- analyzer 能从合成数据和 smoke 结果生成全部七张 CSV。
