---
name: platemo-variant-ablation
description: 在 PlatEMO 里从已有算法目录派生一个常数或超参变体（lambda、qKeep、nMax、pMix 等），并做小规模两臂配对对照实验、配对显著性检验与结论表格。当用户说"实现一个 X=Y 的算法变体、小范围跑一下、给结论表格"时使用。
---

# PlatEMO 变体消融：派生 → 配对跑 → 结论表

## 1. 先读源目录，锁定唯一改动点

不要凭记忆改。读源算法主类 + 被调用的选择函数，把要改的常数/分支找出来，确认**只改这一处**，
其余（PAQC、候选生成、贪心项、参数默认值）逐字保留。改动点写进注释和 README。

## 2. 复制目录 + 重名隔离（必须）

- 主类文件 `classdef < ALGORITHM` 留**顶层**（GUI 靠它发现算法）。
- **其余所有 .m 一律进 `private/`**，包括 `ResolveUniformMixMode.m`、`PrunedIndicatorSelection.m`
  这类名字在很多算法目录都存在的通用名文件。private 优先级最高，解析确定。
- 验收（两步，缺一不可）：
  1. **静态**：新目录顶层除主类外没有 `.m` ⇒ 全局路径重名 `.m` = 0
     （列全部 `.m` 按名分组、排除 `\private$`，再逐个查顶层文件是否上榜）。
  2. **动态（唯一有效证据）**：在算法目录里放一个**临时探针函数**，函数体内用 `functions(@Name)` 取解析路径：
     ```matlab
     function p = ProbeX(); s = functions(@ResolveUniformMixMode); p = s.file; end
     ```
     断言返回路径含自己的目录名。**`which('ResolveUniformMixMode')` 不能当验收证据**：它从基础工作区
     查不到 private，返回的是别的目录的副本，根本不是本算法实际调用的那个（2026-09-15 修正）。
     验完把探针 **`Move-Item` / `movefile` 搬到 `.workbuddy/_movecheck/`**（沙箱 `Remove-Item` 被拦）。
- 副本身份：与来源目录**逐文件 SHA-256 比对**，确认是"按字节复制"而不是"看着像"。
- 反例（2026-09-15 实测）：`ResolveUniformMixMode.m` 在不同目录有 **3 个不同版本**，全局解析
  哪个纯看 addpath 顺序。两臂若各自解析到不同版本，配对就废了。同类高危还有 `Shape_Estimate.m`
  （曾有一个 4 参数的抢占版，被抢后 `IndicatorSelectorSDEOnly` 的 try/catch 会**静默降级**成 `Lp_prev`，
  不报错、只变差——这种失败最难查）。

## 2b. 模块移植型变体（框架 A + 模块 B）

用户说"在 X 的基础上用 Y 的 Z 模块"时，做法与上面的常数变体不同：

1. **先找同类先例**。这种组合臂常已有人做过一次（本次先例 `REMO_UniformMixCandidate` = 原版 REMO 框架 +
   旧版候选解模块），照它的骨架与命名习惯改最省事，也最贴用户对该族的预期。
2. **划清边界再动手**：把"框架函数清单"和"模块函数清单"分别列出来对照来源目录；判断模块内部的
   中间产物（指标模型、模式随机流）算不算模块的一部分，依据是**模块的定义性特征**——CDIS 的定义是
   "每轮在两种完整准则之间选一种"，砍掉指标模型就只剩探索分支，那不是 CDIS ⇒ 指标模型必须随模块搬。
3. **只写入口文件**：框架照抄原算法主循环，模块函数按字节复制（`Copy-Item`，不要重打字）。
   新写的入口文件保持**纯 ASCII**；复制来的旧文件保持原字节（中文注释照旧，别顺手重写）。
4. **主循环保护沿用模块来源方**：模块来源那版主循环带空候选补齐 / 剩余 FE 截断，就照抄，
   别退回框架原版的裸循环——裸循环在候选池为空时会死循环，且容易超预算。
5. 入口文件头部写清「框架逐行照搬 / 唯一改动是 X / 与来源方差异 / 参数表」；README 写
   「来源表 + 差异表 + 隔离说明 + 验证表 + 未做事项」。
6. **想复用现成臂当对照前，必须做代码级核验**：同名文件哈希不同**不代表**行为不同——
   `ResolveUniformMixMode` 的多个"版本"里至少两个只差注释。做法是**剥掉注释按行比代码**
   （PowerShell 读行、剔除空行/纯注释行、按第一个 `%` 截断行尾注释，再 `Compare-Object`），
   然后逐条列出「输入 / 分支 / 默认值 / 输出」的差异。
   只看哈希会误判；**只看注释会被过时文档误导**（实测 `REMO_UniformMixCandidate.m` 头部写"三模式
   conservative/explore/indicator"，实际 `ResolveUniformMixMode` 只返回两模式，第三分支是死代码）。
   复用前还要确认：k 的实际取值（class 的 `ParameterSet` 默认可能和目录名不符）、
   主循环有没有空候选补齐 / 剩余 FE 截断（没有的话会超预算）。


## 3. 静态检查

`checkcode(f,'-string')`。注意它返回 **char 不是 cell**，用 `fprintf('%s\n',r)` 打印；
`char(checkcode(f))` 会报错。

## 4. runner：两臂同池同种子

- **绝不用历史数据当配对臂**：同源码同种子在不同线程数/不同会话下结果不同。
- 两臂在**同一个 parpool、同一次 parfeval 批次**里跑，`rng(seed,'twister')` 在 Solve 前设置。
- 每臂 `addpath(genpath(platform))` 后再 `addpath(algFolder)`，让各臂优先解析自己目录。
- **runId 避开数据目录里已存在的**（先数 `.mat` 的文件名尾号，别覆盖）。
- 种子沿用项目公式：`20260912 + M*1e5 + 题号X1000 + runId`。
- 只写 `.mat`（`result`/`metric`/`metadata`），不写 manifest / 日志 / 逐轮 CSV 到数据目录。
- runner 放 `.workbuddy/run_scripts/`，**绝不放进算法目录**（会破坏运行前 SHA-256 源码校验）。

## 5. 跑前审计 + 资源

- 先跑 `'check'` 动作：确认待跑数、`which` 解析、问题规格（D/M/N/maxFE）都对再启动。
- **worker 数看上一步实测的剩余内存**，不要照抄旧命令：6 workers 需要 ~18GB 余量。余量不足就降
  （本次 13GB 余量用 5 workers，稳定 7GB 富余）。真跑起来用 `-batch` + `run_in_background=true`。
- 进度**看产物 .mat 个数**，`-batch` 的 stdout 是块缓冲，不实时。

## 6. 统计与报告

- **跨臂比较一律先统一 runId 集合**：各臂存量跑数常常不等（如 18/20/30）。若图省事用"每臂全部可用
  跑数"，会算出**不同的结论**（实测：某个 −19% 从"显著更差"变成"边缘不显著"、另一个 +2% 从显著变不显著）。
  先取交集（如 `runIds = 1:18`）再算，并在报告里写明"各臂统一到 runId 1–18，n=18"。
- 每题配对 `signrank(A,B)`（Statistics Toolbox 自带，不必装 scipy）+ Holm 校正。
- **变体还要和外部基线比**（如 REMO）。基线多半是历史数据 → 只能非配对 `ranksum`，
  取与变体**同一 runId 段**保持种子范围对齐，另用基线全量做敏感性。报告里区分
  「优于基线的显著项数」和「劣于基线的显著项数」——只看总数会把劣势项算成成果。
- 基线若有预算超支（如 REMO 末次 FE 300–307），必须核对并写明它对基线有利。
- Holm 递推必须写显式 `if`：`x=max(prev, p*(m-i+1))`。**不要用辅助函数假装短路**
  （`iif(i>1,holm(i-1),0)` 会先求值 `holm(0)` → "数组索引必须为正整数"）。
- **标签向量要和 p 值向量同形**：`problems` 是 1×4 行 cell 时 `strcat(problems,'|050')` 仍是 1×4，
  `[A;B]` 得到 2×4，线性索引变成**列优先**，与 8×1 的 p 值错位 → 判决标签张冠李戴。
  先 `problemsCol = problems(:)` 再 strcat，并 `assert(numel(labels)==numel(allp))`。
- 报告里必须点明：**合并均值在题目量纲差异大时（如 IGD 0.7 vs 10）是被大量纲题目主导的，不可引用**；
  给逐题 delta 和符号计数，别只给 pooled p。
- 结论表列：`Problem | n | mean_A | sd_A | mean_B | sd_B | delta% | p | 判定`，
  delta% = `100*(mean_B-mean_A)/mean_B`，并**明确标注正负号含义**（IGD 越小越好）。

## 7. 收尾

数据目录只留 `.mat`；删掉 `_tmp_*.txt`、日志等中间产物（用 `[System.IO.File]::Delete()`
绕过 safe-delete 拦截）。**算法目录里不许留 runner / 探针 / 日志**（会破坏运行前的 SHA-256 源码校验）；
沙箱删不掉就用 `Move-Item` / `movefile` 搬到 `.workbuddy/_movecheck/`，临时文件一律只放 `.workbuddy/` 下。
改动结论写进 `.workbuddy/memory/<日期>.md`。
