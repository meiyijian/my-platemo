# NoBatchDict 消融实验监控 — 自动化执行记录

任务：巡检 NoBatchDict 两臂（noCDIS / noPAQC）**M=10 块** = 2 臂 × 16 题 × 20 跑 = **640 个 .mat**；不足 640 且无 MATLAB 进程则续跑；满 640 则收尾出 2 张 xlsx。
**M=20 两块已被用户明确搁置 —— 不启动，也不因 20目标 目录缺文件判失败；ETA 只按 M=10 算。**
结果目录：`C:\Users\lsx\Desktop\REMOandDREMO测试集\{10目标\n30, 20目标}\REMO_noBatchDict_{noCDIS,noPAQC}`
日志目录：`D:\PlatEMO-master\PlatEMO-master\.workbuddy\ablation_logs`

## 环境要点（每次照做）
- Bash 工具链本机不可用 → 一律 PowerShell；且**PowerShell 工具的 Stdout 在本会话恒为空**，必须 `| Out-File -Encoding utf8 <file>` 后再 Read 才能看到结果。
- python：`C:\Users\lsx\.workbuddy\binaries\python\envs\default\Scripts\python.exe`
- 进度脚本：`.workbuddy\run_scripts\progress_nbd.py`；续跑：`RunNBD_AblationAll(5)`；收尾：`FinishNBD_Ablation`；出表：`build_nobatchdict_tables.py` → `C:\Users\lsx\Desktop\AdaMao实验表\消融实验\nobatchdict版本\`
- 20目标目录是**扁平**结构（无 n30 层），臂目录按需惰性创建：未启动的组目录不存在属正常，不是异常。

## 执行历史

### 2026-09-18 22:41 — 第 1 次巡检（状态：进行中，未收尾）
- 进度：**170/1280**（work-weighted 14.98%）。逐组：noCDIS M=10 = 170/320（53.1%）；noCDIS M=20 = 0/320；noPAQC M=10 = 0/320；noPAQC M=20 = 0/320。
- 磁盘核对：仅 `10目标\n30\REMO_noBatchDict_noCDIS` 存在，实测 .mat = 170，非 .mat 文件 0 个（目录干净，符合"只留 .mat"）。其余三组目录尚未创建。
- 进程：MATLAB 存活 7 个（client 1 + 5 worker，19:36–19:37 启动）。20 s 双采样确认 5 个 worker 各推进约 10.5 s CPU，均匀无卡死 → **未触发续跑**。
- ETA：脚本给 `~16.9 h → 2026-09-19 15:35`（按 elapsed 线性外推）。本轮修正：剩余 1110 跑，按"实测速率"算约 18.5 h（→ 09-19 17:10），按"脚本 expected 分组耗时"算约 23.3 h（→ 09-19 22:00）→ 合理区间 **09-19 15:35–22:00，中位约 18:00**。
- 结论：一切正常，本次未做任何写操作（未续跑、未生成表）。

### 2026-09-19 01:47 — 第 2 次巡检（状态：进行中，未收尾）
- 进度（M=10 目标口径）：**340/640**。noCDIS M=10 = **320/320 已满**（末文件 01:18:39 WFG9_r18）；noPAQC M=10 = **20/320**（6.2%，首个批次 01:19 起落盘）。命中任务步骤 2 的"不足 640"，但**有 MATLAB 进程** → 不续跑。
- 进程证据：7 个 MATLAB.exe，命令行确认为 `RunNBD_AblationAll(5,10); disp('SWEEP M10 DONE')`（pid 10328/36828 为 client，23:40:55 起；pid 4932/3012/28964/18892/33896 为 5 个 parpool worker，23:41:09 起，各 ~2662 s user CPU）。**这轮 run 是上一次巡检之后由别处重启的**，同一会话串行跑完 noCDIS 再跑 noPAQC，且 Ms=10 不会自动进入 M=20（脚本第 2 参数限定），符合"二十目标搁置"。
- 速率实测：noPAQC 臂 20 跑 / ~25.5 min ≈ **47 跑/h**（5 worker × 6.2 min/跑，与 `recorded` 口径 2.07h/20 = 6.21 min 吻合）；noCDIS 臂速度为 5.19 min/跑。
- ETA 修正：剩余 300 跑 → 约 6.4 h；乐观（按 noCDIS 速度）07:20，保守 08:40，**中位约 09-19 08:10**。脚本自报的 17:17 是按 M=10+M=20 四组外推，**已作废**。
- 本次未做任何写操作（未续跑、未出表），仅生成巡检临时日志。

### 2026-09-19 04:49 — 第 3 次巡检（状态：进行中，未收尾）
- 进度（M=10 目标口径）：**484/640（75.6%）**。noCDIS M=10 = **320/320 已满**（末文件 WFG9_r18 @ 01:18:39）；noPAQC M=10 = **164/320（51.2%）**，末文件 WFG1_r3 @ **04:48:03**（距采样仅 1 min，活跃）。M=20 两行均 0/320（搁置，不启动）。
- 磁盘核对：两目录 total=mat 且 **nonmat=0**（干净，符合"只留 .mat"）；SUM_MAT=484，与进度脚本一致。
- 进程：7 个 MATLAB.exe，命令行确认为 `RunNBD_AblationAll(5,10); disp('SWEEP M10 DONE')`（client pid 10328/36828 @ 09-18 23:40:55；5 worker @ 23:41:09）→ **规格正确，仍在跑**。命中"不足 640 但有进程" → **未续跑**。
- 速率：noPAQC 3.03 h 内 20→164 = 144 跑 ≈ **47.5 跑/h**（与前轮 47 跑/h 一致）。剩余 156 跑 → 约 3.3 h。
- ETA 修正：**~2026-09-19 08:05**，区间 07:30–08:40。脚本自报 18:07 按四组外推，已作废。
- 本次未做写操作（未续跑、未出表），仅生成巡检临时日志 progress/proc/dircount。

### 2026-09-19 07:52 — 第 4 次巡检（状态：进行中，未收尾）
- 进度（M=10 目标口径）：**633/640（98.9%）**。noCDIS M=10 = **320/320 已满**（末文件 WFG9_M10_r18 @ 01:18:39）；noPAQC M=10 = **313/320（97.8%）**，末文件 WFG9_M10_r2 @ **07:52:03**（与采样同分钟，活跃；已跑到最后一道题 WFG9）。M=20 两行 0/320（搁置，未启动）。
- 磁盘核对：两目录 total=mat 且 **nonmat=0**（干净）；SUM_MAT=633，与进度脚本一致。
- 进程：7 个 MATLAB.exe，命令行确认为 `RunNBD_AblationAll(5,10); disp('SWEEP M10 DONE')`（client pid 10328/36828 @ 09-18 23:40:55；5 worker @ 23:41:09，各 ~10250 s user CPU）→ 规格正确，命中"不足 640 但有进程" → **未续跑**。
- 速率：近 30 min 新增 25、60 min 新增 50 ≈ **50 跑/h**（较前轮 47.5 略快）。
- ETA 修正：剩 7 跑 → 约 8–10 min → **约 2026-09-19 08:00–08:10 达 640**。脚本自报 19:08 按四组外推，作废。
- 本次未做写操作（未续跑、未出表），仅生成巡检临时日志。
- 附带：`memory/MEMORY.md` 因超注入上限被截断 → 把「GGP 坐标 / NoBatchDict 坐标 / 论文资产 / λ 上下文敏感性」四节详情外迁至新建的 `memory/MEMORY-details.md`，主文件重写为「规则 + 索引」版（未删信息）。

## 待办 / 下次注意
- 下次巡检判据：只看两个 M=10 目录合计是否 640。**若 ~08:30 后仍不足 640 且进程消失 → 再续跑**（`run_in_background=true`）。
- 第 3 次巡检实测：预期 **~08:05（区间 07:30–08:40）** 达 640；下一次巡检大概率正好触发收尾流程（Finish → 出 2 张 xlsx → present_files → 汇报 +/-/= → 清理 ablation_logs 与 `_*.txt`/`_smoke`，保留 run_scripts）。
- PowerShell 坑：`foreach(...){...} | Out-File` 会 exit 1 且不落盘 → 必须先把结果 `+=` 进数组变量再 `| Out-File`。
- 注意：本轮 run 不是本次自动化拉起的，而是外部重启 —— 巡检时**必须先查命令行**确认在跑的是 `RunNBD_AblationAll(5,10)`，别只看"有 MATLAB 进程"就放心；若发现跑的是 `(5)` 或 `(5,[10 20])` 需提醒用户。
- 3 分钟采样窗口内可能 0 新文件（5 worker 批量落盘，间隔 ~6 min），**不能据此判卡死**；应改看"最近 30/60 min 新增数"或文件 mtime。
- 提交进度判断时注意运行是**按组串行**推进的（先 noCDIS M=10 再 noPAQC M=10），不要按 4 组平均铺开估 ETA。
- 收尾（两臂各 320）后：FinishNBD_Ablation(10) → build_nobatchdict_tables.py → present_files **2 个** xlsx → 汇报 +/-/= 计数 → 清理 ablation_logs 及 .workbuddy 下本次 `_*.txt`/`_smoke` 临时文件（保留 run_scripts）。收尾完成后再次巡检只回"十目标已完成"。
