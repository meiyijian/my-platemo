# Automation: REMO_UniformMix_Pruned_Weighted_Lambdat030 M=20 完整性校验与补跑

## 2026-09-15 08:40 — 第 1 次执行（用户中途要求暂停存档）

**结论：未补跑**（8 个 MATLAB 切片存活，仍在推进；规则要求全部退出才补跑）。

### 执行内容
- 全量扫描数据目录 `D:\REMOandDREMO测试集\20目标\REMO_UniformMix_Pruned_Weighted_Lambdat030`：**258/320** 完成，缺失 62 跑（WFG2-9 各自 run 未满）。
- 结构校验（258 个文件全量，非抽样）：变量集合 `{result,metric}` 正确、`result` 30×2、末行 FE=300、D 值正确（WFG2/3=31）。全部通过。
- 清理：数据目录中的游离 `_runlog_part8of16.csv` 已移到 `logs\runlog_s2\`。

### 核心发现（重要）
1. **实验停滞 5.6 h 的根因 = 本机进了 Modern Standby（S0 待机）**。Kernel-Power Event 506 @ 02:55:13（原因 `AC/DC Display Burst`）、Event 507 @ 08:33:56（原因 `Input Mouse`）。8 个切片在 02:41–02:49 同时停写盘。
2. **屏幕自动关闭（AC VIDEOIDLE=600 s）会触发 S0 待机，即使 STANDBYIDLE=0（永不）也无效** —— 这是 Modern Standby 设备的固有行为。
3. **次生数据缺陷**：待机窗口内正在执行的那一跑 `metric.runtime` 被记为 ~21000 s（真实 ~310–450 s）。预计 WFG2–WFG9 各 1 个文件受影响（已确认 4 个）。**IGD/Pop 有效**（终止按 maxFE=300 计，与墙钟无关）。按约束未删未覆盖。

### 产出
- 存档交接文档：`PlatEMO\Experiments\REMO_UniformMix_Pruned_Weighted_Lambdat030_M20\RESUME_STATUS.md`
- 已通过 present_files 交付。

### 下次执行要点
- 先查 `tasklist | grep -c MATLAB.exe` 是否归零；归零且仍有缺失才补跑（全局索引：DTLZ1-7=1-7，WFG1-9=8-16）。
- 补跑前**务必先执行 `powercfg /change monitor-timeout-ac 0`**，否则会再次被待机中断。
- 注意识别 `runtime > 600 s` 的污染文件并向用户报告。

## 2026-09-15 08:44 — 用户中途要求停止实验（非本 automation 触发）
- 已 `taskkill /IM MATLAB.exe /F` 停止全部 8 个切片。停止时 **264/320**，剩 56 跑。
- 复核：264 文件全部合格，无损坏、无 `.tmp.mat` 残留，数据目录只含 `.mat`。
- harness 崩溃安全性已核实（写 `.tmp.mat` → 原子改名；跳过前 `localValidateRunFile` 校验）→ **中途杀进程安全**。
- 待机污染最终 8 个（WFG2_r12、WFG3_r13、WFG4_r13、WFG5_r13、WFG6_r13、WFG7_r12、WFG8_r13、WFG9_r13）。
- 交接文档已更新为最终版：`...\REMO_UniformMix_Pruned_Weighted_Lambdat030_M20\RESUME_STATUS.md`（含逐 part 缺失 run 清单 + 续跑命令 + 防待机设置）。
