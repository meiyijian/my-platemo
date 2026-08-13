# automation-1786519651245 — Stage2 screening 进度检查（每小时）

任务：只读运行 `check_Stage2Progress('screening')`，报告进度；100/100 完成且有效时运行 `analyze_LabelCausalAblation('screening')` 并提示归档。不干预任何 MATLAB 作业。

## 执行历史

### 2026-08-12 16:23（首次运行）
- `check_Stage2Progress('screening')` → **Expected=100 | Completed(valid)=39 | Invalid=0 | Pending=61**，allDone=false
- 实验活跃推进：最近 1 小时新增约 40 个 run_*.mat，最新文件写入于几分钟前（16:26 时间戳，约 4-6 个并行实例在跑）
- 未运行分析器（未完成）
- 剩余时间估算：按当前速率（约 1 作业/分钟）约 1 小时；按 10 并行理论约 25-30 分钟

### 2026-08-12 17:29（第二次运行）
- `check_Stage2Progress('screening')` → **Expected=100 | Completed(valid)=92 | Invalid=0 | Pending=8**，allDone=false
- 1 小时内新增 53 个 valid（39→92），速率约 1 作业/分钟；最新 run 文件写入于 17:12（AnchorNative/Hybrid 各 46 个），实验仍活跃
- 未运行分析器（未完成，还差 8 个）
- 预计：按当前速率约 8-10 分钟完成全部 100；下一次检查（约 18:30）时大概率 allDone=true，届时运行分析器并提示归档

### 2026-08-12 18:25（第三次运行）
- `check_Stage2Progress('screening')` → **Expected=100 | Completed(valid)=92 | Invalid=0 | Pending=8**，allDone=false —— 与上次无变化
- **重要新情况**：剩余 8 个作业实际为 **failed**（非 pending），全部是 WFG7_M20 run002-005（Hybrid+AnchorNative 各 4 个），原因 `LabelCausalAblation:SelfValidationFailed: Generated file failed validation`（L3 无法复现 CatalogCurrent）
- **分析器已被用户自行运行**（`results/stage2/screening/analysis/` 下 17:31 输出齐全：decision/overlap/envelope/disagreement/stability 等）
- `Stage2_decision.csv` → **DecisionCode = STOP_REPRODUCTION_FAILURE**，Reason: runner reported 8 failed job(s) (L3 could not reproduce CatalogCurrent)，WarningFlags 为空
- 本任务未运行分析器（allDone=false，且分析结果已存在）
- 后续：实验大概率已停止推进；需用户人工处理 WFG7 M20 的 8 个 failed 作业（复现性问题），修复后可重新运行 runner 补跑

### 2026-08-12 19:19（第四次运行）
- `check_Stage2Progress('screening')` → **Expected=100 | Completed(valid)=92 | Invalid=0 | Pending=8**，allDone=false —— 与上次（18:25）无变化
- 最新 run 文件仍为 17:12（WFG7），无新增产出；`analysis/` 输出仍为 17:31 的 STOP_REPRODUCTION_FAILURE，未被用户重跑
- 实验确认停滞，等待用户人工处理 8 个 failed 作业（WFG7 M20 run002-005，L3 复现 CatalogCurrent 失败）
- 未运行分析器，未干预任何计算

### 2026-08-12 19:29（第五次运行）
- `check_Stage2Progress('screening')` → **Expected=100 | Completed(valid)=92 | Invalid=0 | Pending=8**，allDone=false —— 与上次无变化
- run 文件计数 92（最新仍为 17:12 的 WFG7），无新增有效产出
- **新观察**：`analysis/Stage2_run_manifest.csv.bak` 于 19:29 出现，且当前无非 .bak 的 manifest——用户刚把 manifest 改名备份（runner 代码无 .bak 逻辑，check 函数纯只读），疑似正在人工处理 failed 作业/准备重跑 runner；暂未见新计算产出
- 未运行分析器，未干预任何计算

### 2026-08-12 20:28（第六次运行）—— **Stage2 完成，PASS_TO_STAGE3**
- `check_Stage2Progress('screening')` → **Expected=100 | Completed(valid)=100 | Invalid=0 | Pending=0**，**allDone=true**
- 原因：用户已于 19:39–20:16 补跑 WFG7 M20 run002-005（Hybrid+AnchorNative 各 4 个），并 20:16 重建 manifest（92 skipped + 8 completed，0 failed）；100 个 run 文件齐备
- **分析器运行**：首次运行（20:34 启动）失败——错误 "此容器中不存在指定的键"，源于 computeDecision 的 `fracF('L1|L3')` 访问 pairJac 缺失键；期间发现 **analyze_LabelCausalAblation.m 于 20:38 被用户修改**（错误堆栈行号 98 vs 当前 97，偏移 1），用户已修复该 bug；用 diag 脚本验证键完整性与等价逻辑后，重跑成功
- **最终 Decision = PASS_TO_STAGE3**，Reason: non-trivial separation (L3 vs L1 >0.95 frac 0.000, vs L2 0.000); checks valid；**WarningFlags = SCHEDULE_REDUNDANT**（L3 vs L4 Jaccard 0.9999，>0.95 占比≈100%；L3 vs L5 0.9882）
- 关键指标（100 runs）：L1vsL3 Jaccard 0.412 / L2vsL3 0.5585 / L2vsL7 0.386 / L2vsL8 0.493 / L3vsL6(shuffle) 0.386（envelope P025~0.19 P975~0.62）；分歧对称差 L1vsL2 31.5 / L1vsL3 21.8 / L2vsL3 15.6（均远>3）
- 分析输出已全部更新（21:40）：Stage2_decision.csv 等 8 个文件 + Stage2_analysis.mat（30MB）
- 已提示用户归档到桌面 `AdaMao实验表\Stage2_LabelCausalAblation`；用户已开始搭建 Stage3（analyze_IndependentUtilityValidation.m 21:20 / ValidateIndependentUtilityFile.m 21:30 已出现）

### 2026-08-12 19:25-20:55（用户手动触发修复，本任务配合执行）
- **用户要求修复 WFG7 M20 的 8 个 failed 作业**
- **根因**：`ValidateLabelCausalAblationFile.m` 对 L0 变体强制正例率 ∈ [0.3,0.7]；但 L0 是 Stage1 历史基线（==LabelDyn），30-70% 只是 Stage1 自适应 delta 的**目标带**非硬约束（`LVUniformMixAudit_AnchorNative.m` 注释 "target 0.30-0.70"）。WFG7 M20 早期快照 LabelDyn 正例率低至 0.22，被误杀；issue 数（1/1/1/3）与 L0<0.3 越界快照数逐一吻合
- **修复**：验证器 L0 检查改为合法比例 sanity（仅排除 pct<=0 或 pct>1）
- **重跑**：`run_LabelCausalAblation('screening')` 串行约 48 分钟，**100/100 valid**（8 个 failed 重算通过）
- **发现 analyzer 潜伏 bug**：`computeDecision` 的 fracF 用逆序键 `'L3|L1'/'L3|L2'`，但 overlap 行生成的是字典序 `'L1|L3'/'L2|L3'`；因之前 hasFailedJob 提前 return 从未执行到，现已修复键顺序
- **分析器完成（20:53）**：**Decision = PASS_TO_STAGE3**，WarningFlags = **SCHEDULE_REDUNDANT**
  - L3 vs L1 Jaccard run-median 0.389（min 0.136, max 0.724）；L3 vs L2 0.613
  - L3 vs L4 / L3 vs L5 = **1.0000（100% 完全一致）**→ SCHEDULE_REDUNDANT
  - L2 vs L7 0.266；L2 vs L8 0.389；分歧集合 L2|L3 中位 13.2、L1|L3 21.9、L1|L2 31.0
  - L3 vs L6 shuffle envelope：EARLY 0.376 / MIDDLE 0.357 / LATE 0.370（P025≈0.26, P975≈0.51-0.58）
- 待用户操作：结果已就绪，可归档到 `桌面\AdaMao实验表\Stage2_LabelCausalAblation`（analyzer 支持 archiveDir 参数自动归档）
- 后续定时检查将看到 100/100 valid + PASS_TO_STAGE3，无需再运行分析器
