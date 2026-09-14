# 项目长期记忆（PlatEMO AdaMaO 研究）

## 本机环境硬事实
- Bash 工具可用：每条命令前加 `export PATH="/c/Users/lsx/.workbuddy/binaries/PortableGit/versions/1.2.0/usr/bin:/c/Users/lsx/.workbuddy/binaries/PortableGit/versions/1.2.0/mingw64/bin:$PATH"`。PowerShell 工具 stdout 不回显，别用。
- MATLAB R2021b：`/d/software/mathlab/bin/matlab.exe`。`checkcode`/`pcode` 在 `-batch` 下可用。UTF-8 .m 中文字面量正常，中文路径不必转 GBK。
- MATLAB `-batch` 退出偶发 `0xc0000374 堆损坏`：发生在写盘后，数据安全；长跑必须配"进程守护 + 断点续跑"（supervise_part.sh），并设 `maxNumCompThreads(4)`（机器 8C16T/32GB）。
- Edit 工具偶发报成功但未落盘：关键编辑后必须 Read/Grep 复核；.m 行级插入用 sed 更稳。
- 本仓 .m 是 CRLF；Write 产出 LF，需 `sed -i 's/$/\r/'` 补回。
- Python venv：`C:/Users/lsx/.workbuddy/binaries/python/envs/default`，python.exe 在 `Scripts/` 下（openpyxl 已装）。

## 关键坑（血泪）
- 固定种子不能 `rng()`+`platemo()`（本地 platemo.m 会 `rng('shuffle')`）；必须直接构造 problem/algorithm，Solve 前 `rng(seed,'twister')`；模式流需传 `'run',r` 才独立（`10000000+runId`）。
- 加权前用欧氏距离，不能用平方距离。
- WFG 的 D 会按 `ceil((D-K)/2)*2+K`（K=M-1）自动调整：M=10/20 时 WFG2/3 D=31；M=15 与 M=5 时 WFG2/3 保持 D30/D10；M=8 时 WFG2/3 D=11。文件名用 Problem.D，别手工"纠正"。
- harness 里 Solve 后必须先 `ALG.CalMetric('IGD')` 再取 metric（struct 是值类型）。
- 三版本间无共同初始样本（仅 run 编号对齐）→ 用 exact Wilcoxon 秩和；同种子同 run 号的两组才用配对设计（参考 `compare_qkeep.py`）。

## 数据集与实验框架
- 数据根 `D:\REMOandDREMO测试集\<M>目标\n<D>\<算法名>\`，文件名 `<算法>_<问题>_M<M>_D<D>_<run>.mat`，内容 `result`（{FE,Pop} cell）+ `metric`（runtime/IGD，IGD 末位=最终值）。
- 标准模板：`PlatEMO/Experiments/<名字>/run_*.m`（4 分区轮转、断点续跑、.mat 带 metadata）+ `verify_*.py`（校验 seed/params/FE）+ `tmp/supervise_part.sh`（已泛化：`ALG/FOLDER/PARAMS/HARNESS/FUNC/OUTDIR/SCRATCHROOT` 环境变量）。多次实战验收（288/270 跑规模）。
- Weighted 论文种子：`20260912 + M*100000 + p*1000 + r`（p：DTLZ1-7→1..7，WFG1-9→8..16），modeRunId=1，save=30，参数 `{3000,0.50,0.25,0.70,6}`。
- 「参数变体复制」验收标准：旧类+旧参 / 旧类+新参 / 新类+新参 三组同种子；后两组须差 0 且与第一组不同。

## Weighted WFG sweep 进度（2026-09-14）
- M=15 与 M=8(D=10) 各 270/270 已全部完成并 verify COMPLETE；per-run CSV 在各自数据目录。M=15 报告：`tmp/weighted_wfg_m15/chain_final_report_20260914.md`。
- M=5(D=10) sweep（harness `run_WeightedWFG_M5D10.m`，数据 `...n10\REMO_new2_..._Weighted`，scratch `tmp/weighted_wfg_m5/`）：09-14 11:05 起停滞于 159/270（4 个 MATLAB 进程消失、日志尾部无报错），剩 111 跑 ≈55min（4 并行 @ ~2 跑/min），待重启 supervise 续跑。

## PWGGP GoodGroupPrecision 正式跑（09-14）
- `run_TopFourPartition(k,8)`：8 分区×25=200（DTLZ2/3/4/7 × M10/20 × 25 跑），maxFE=500，11:56 启动；单跑 wall ~715–820s 且随负载缓慢上浮，8 并行约占 11 核。
- 输出在内层 `D:\PlatEMO-master\PlatEMO-master\PlatEMO\Experiments\REMO_new2_AdaMaO_PrunedWeighted_GoodGroupPrecision\results\`（raw\formal、manifests、logs）；`logs\partitionN_status.json` 含 Completed/Total/MeanWallSeconds，算 ETA 直接读它。
- ⚠️ `RunPaperWeighted30.m` 原配的 C 盘数据根已消失（C 盘清理）：KRVEA_100/PCSAEA_N100/Weighted M20/09-12 补跑全丢；D 盘老基线（M=15 各算法 480）完好。重跑前删 `...Weighted/diagnostics/paper_30runs/RUNNING.lock`。

## UniformMix 参数削减族结论
- Pruned（五项同时删减，组合版）在 DTLZ2/5 退化；回填 0.75 质量+0.25 距离权重（Weighted）后缓解 → "持续质量约束"是第一嫌疑。qKeep 0.70 vs 0.80 消融 8胜8负无系统差异，可排除。
- PIEAOnlySelection / FixedIndicatorAlways 在 DTLZ7 崩 2.35×，不可保留。

## 论文（PACDIS）
- 命名：HPDC-MaOEA→PACDIS，HPC→PAQC（PBI-Assisted Quality Classification），候选模块→CDIS；旧图标注需同步。
- `论文写作/HPDC-MaOEA_1param.tex`：探索分支 `A_k=R̃+β·E_k`，β→0 对应被否定的纯关系排序格，β 敏感性是必做 \TODO。
- 09-11 曾发生 论文写作/ 227 文件批量进回收站（非会话所为），已 `git restore` 恢复；origin/master 是离线安全网。

## 归档约定
- 算法级笔记/报告放对应算法目录 `notes/`，诊断放 `diagnostics/<主题>_<日期>/`；项目级周报告放 `D:\PlatEMO-master\docs\`；实验 xlsx 在 Desktop `AdaMao实验表/`。
- 分工：用户亲自跑重活，AI 负责开发/归档/自动化；长任务先预估时长与排程间隔。

## 默认实验参数
- N=100，D=30（论文 WFG sweep 用 D=10 系），maxFE=300，gmax=3000（代理内部 GA 上限，与总预算不同）。
