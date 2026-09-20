# 给单个算法跑十目标全系列 + 出 IGD/IGDp 对比表（打包版）

把 2026-09-20 给 `SAMOEATL2M_N100` 走完的一整套流程固化下来。以后换任何算法，
**复制这一包 → 改算法名和路径 → 按阶段跑**即可。

> 本目录是**打包副本**；日常仍在 `.workbuddy/run_scripts/` 下编辑原件。
> 两边改动请手动同步（包内文件与原件逐字节相同，可用 SHA-256 核对）。

---

## 一、文件清单

### 跑实验
| 文件 | 角色 | 说明 |
|---|---|---|
| `RunSAMOEATL2M_N100_M10.m` | **runner 模板** | 三模式：`('smoke',W)` 五題探针 / `('run',W)` 全量 320 跑 / `('check')` 盘点。幂等可重启、原子写入、源文件 SHA-256 校验、逐轮进度文件 |
| `ProbeSAMOEATL2M.m` | **路径体检** | 打印每个 helper 在 `Solve` 前后解析到哪个目录。**外部算法必做**，见「踩坑」第 1 条 |
| `TimingSAMOEATL2M.m` | 测速探针 | 单跑计时 + 逐轮进度 + IGD 轨迹。可传类名，用来估 ETA |
| `MergeIGDpForDir.m` | **补 IGDp** | 给只有 `IGD` 的 `.mat` 逐快照补 `IGD+`，`save(...,'metric','-append')` 合并并回读校验。`(alg, M, workers, dtlz7FinalOnly, runsOverride)` |

### 出对比表
| 文件 | 角色 | 说明 |
|---|---|---|
| `BuildSAMOEAColumn.m` | **算新基线那一列** | 读 runs 1–20 的 IGDp，出 mean/std/符号 CSV。口径与 `BuildTable15Data.m` 逐项一致 |
| `build_samoea_table.py` | **组装 xlsx** | 在现有主表副本上追加一列并另存；**同时重算全行蓝标** |
| `verify_samoea_n100_m10.py` | **完整性校验** | 查文件数、每题跑数、`FE==maxFE`、种子公式、IGD 有限 |
| `check_blue_marking.py` | 蓝标自查 | 列出每行蓝标所在列，确认「一行恰好一个」 |
| `CompareExtra_Paper.m` + `build_compare_extra_paper.py` | **通用对比表** | 任意"额外基线 × M"对论文锚点的对比表（列序 + 符号 + 蓝字） |
| `CompareFE500Significance.m` | 显著性速查 | 多基线对指定锚点的 ranksum `+/-/=`，只打印不落盘 |

---

## 二、流程（按顺序，每步都有验收）

### 阶段 1　路径体检（**外部算法必做**）
```
matlab -batch "addpath('<repo>\.workbuddy\run_scripts'); ProbeSAMOEATL2M"
```
看两段输出：`Solve` **前**（纯 genpath 顺序）和**后**（算法目录被置顶）。
- 只有 `Solve` 后的那一段才算数——`ALGORITHM.Solve` 里的 `addpath(fileparts(which(class(obj))))`
  （**addpath 默认 `-begin`**）会把算法目录提到最前。
- 若算法目录里**缺** `dacefit` 这类共享文件，记录它实际来自哪个目录（写进 metadata，论文可追溯）。
- 记住：**runner 里记录源文件哈希必须用 `fullfile(root,name)`，不能用 `which`**，否则客户端记录的
  是"未置顶时"的解析结果，worker 里一校验就全失败。

### 阶段 2　测速（决定跑量与排程）
```
matlab -batch "... TimingSAMOEATL2M(300,'DTLZ2',10,30,'<类名>')"
```
看 `DONE ... wall` 与逐轮日志。**每轮耗时通常随存档增长**（Kriging 重训），别用早期速度线性外推。
同时记录资源画像（内存/worker、CPU 利用率），据此定 worker 数。

### 阶段 3　跑全系列
```
matlab -batch "... RunSAMOEATL2M_N100_M10('smoke',5)"   # 先 5 題探针
matlab -batch "... RunSAMOEATL2M_N100_M10('run',5)"     # 确认无误再全量
```
- roster 与规格**固定**：16 題（DTLZ1–7 + WFG1–9）× **runs 1–20**，`N=100 M=10 D=30 maxFE=300 save=30`。
- 种子 `20260912 + M*100000 + 题目规范序*1000 + runId`
  （**16 題规范序 DTLZ1–7 = 1–7、WFG1–9 = 8–16，所以 WFG3 = 10**）。
- 长跑用 `-batch` + `run_in_background=true`；进度**看数据目录 `.mat` 个数**，stdout 是块缓冲。
- ⚠️ 探针模式与正式模式的**题号映射必须同源**，别手抄（本次就手抄错一位，见踩坑第 4 条）。

### 阶段 4　补 IGDp（若算法本身只存 IGD）
```
matlab -batch "... MergeIGDpForDir('<类名>',10,5)"
```
M=10 的 320 跑约 **4.4 min**。DTLZ7/M=20 强制串行（参考集 524288 点，进池会崩）。

### 阶段 5　出对比表
```
matlab -batch "... BuildSAMOEAColumn(10)"          # -> samoea_column_M10.csv
python build_samoea_table.py --m 10 --csv <csv>    # -> <主表名>_SAMOEA.xlsx
```
- 主表模板 = `C:\Users\lsx\Desktop\AdaMao实验表\lambdat030版本\lambdat030nobatch{十,十五,二十}目标IGDp.xlsx`
  （A1:K18，末列 NoBatchDist 是锚点，不带符号）。
- **新列追加在最后一列**；其余 11 列逐字保留。

### 阶段 6　收尾校验
```
python verify_samoea_n100_m10.py     # 320/320、FE=300、种子公式
python check_blue_marking.py         # 每行蓝标恰好 1 个
```
数据目录**只留 `.mat`**；临时文件与日志一律出：

---

## 三、固定口径（不要临时改）

| 项 | 值 |
|---|---|
| 问题集 | DTLZ1–7 + WFG1–9（16 題） |
| 规格 | `N=100, M=10, D=30, maxFE=300, save=30`（WFG2/3 的 D 实际 31） |
| 跑数 | runs 1–20（与论文主表同口径） |
| 种子 | `20260912 + M*100000 + 题号*1000 + runId`，`rng(seed,'twister')` 在 `Solve` 前 |
| 落盘 | `result + metric + metadata`，`-v7`，先写 `.tmp` 再 `movefile` |
| 符号 | MATLAB **`ranksum`**（不是 scipy 近似），p<0.05，方向按均值，IGD/IGD+ 是**越小越好** |
| 单元格文本 | `sprintf('%.4e (%.2e)')`，再把 `e+0`→`e+`、`e-0`→`e-` |
| 蓝标 | **行内最低均值**，`#3333E9`；锚点列不带符号 |

---

## 四、换算法要改哪些地方

1. **runner**（`RunSAMOEATL2M_N100_M10.m` → 复制改名）：
   - `algorithm = '<新类名>'`
   - `cfg.root` / `cfg.dataFolder`
   - `sourceManifest()` 里的 `own` 清单（算法目录内的文件用 `fullfile(root,name)`）
   - 输出文件名模板
2. **出表**：`BuildSAMOEAColumn.m` 里的 `anchor` / `newAlg`；`build_samoea_table.py` 的 `--column`。
3. **文档**：主表所在目录的 `README.md` 追加一行带日期的记录。

---

## 五、踩坑清单（都是实测撞过的）

1. **helper 重名**：PlatEMO 用 `addpath(genpath(cd))`，全库同名 `.m` 按路径顺序解析。
   外部算法目录里的 `EnvironmentalSelection` / `predictor` / `dacefit` 极易被别的算法抢占；
   靠 `ALGORITHM.Solve` 的置顶纠正，但**必须验证**（阶段 1）。
   **2026-09-20 实测**（FE500/M=20 七算法体检）：`REMO` 7 个、`PC-SAEA` 2 个、`CSEA` 2 个、
   `SSDE` 1 个、PACDIS 2 个自带 helper 在 `Solve` **前**被抢占，`Solve` 后全部纠正回本目录，
   0 个残留 ⇒ 探针以「`Solve` 后是否仍在别处」为判据是对的。
2. **`sha256` 不是本仓库的函数**。自实现：
   `java.security.MessageDigest` + `typecast(md.digest(),'uint8')` + `sprintf('%02x',...)`。
3. **worker 的 `fprintf` 不回传客户端**：进度必须让 job 写文件（本包写在
   `%TEMP%\<pkg>\progress_<題>_<run>.txt`，每行 `FE=.. t=..`）。
4. **探针模式的题号别手抄**：本次把 WFG3 的规范序写成 11（应为 10），那个文件种子偏了 1000，
   白跑一个 run。**探针与正式模式共用同一张映射表**。
5. **复制参考列样式会带过它的蓝色**：新列若不该蓝，必须显式改色；
   且**加列后要重算整行蓝标**——本次 WFG3 的最小值就从 PIEA 转移到了新基线。
6. **openpyxl 样式代理不可变**：`cell.font.color = ...` 会抛
   "Style objects are immutable"，正确写法 `f = copy(cell.font); f.color = Color(...); cell.font = f`。
7. **协议不兼容的外部算法**：
   - 有的算法**初始设计就超预算**（`NI = 11*D-1`，D=30 → 329 > maxFE=300）⇒ 主循环一次都不进。
     处理：建 `_N100` 变体（**与基类同目录**、独立类名、只改初始化那行 + 加 `assert`），
     照 `PC-SAEA\PCSAEA_N100.m` 的先例。
   - 有的算法**每轮只加 1 个真评估点**（NSGAIII-EHVI）⇒ FE 100→300 要 200 轮，单跑 ~72 min，
     320 跑 @5 workers ≈ **3.2 天**。跑之前必须先测速再决定。
8. **跑前先查 `metric` 字段**：历史基线常常只有 `IGD` 没有 `IGDp`；`metric.IGD` 可能是**轨迹**
   （多个快照）而不是标量，取 `IGD(end)`。
9. 环境：**Bash 工具链不可用**，一律 PowerShell；工具回显常为空，命令
   `| Out-File -Encoding utf8 <临时文件>` 后用 `Read` 读；删文件用 `[System.IO.File]::Delete()`。
10. 🔴 **末次 FE 严禁严格判等 maxFE**（2026-09-20 新增）。按批发评估的算法末次
    `NotTerminated` 落在 maxFE**之上**，实测（M=20）：`REMO` 301–305、`CSEA` 301、
    `SSDE` **500–543**（FE500 档）、`11D-1` 型在 D=31 是 340。
    旧判据 `feList(end) == maxFE` 会把这些文件一律判无效 ⇒ 可重驱的 driver
    **每一轮都重算同一批 run、永不收敛**（ROUNDS 用尽后才停，且验收报 BAD）。
    正确判据：`maxFE <= 末次 FE <= maxFE + slack`。harness 已加 `FESlack` 参数
    （**默认 0 = 旧行为逐字不变**），FE500 实验取 100。
    ⚠️ 同时别忘了：**末次 FE 超过 maxFE 意味着该算法实际多花了几十次评估**，
    跨算法比末值 IGD 时若差异很小，这几十次是有意义的，要在文中交代。
11. **「原版 vs `_N100` 变体」要按 maxFE 档重新判断**（2026-09-20 新增）。
    同一个原版类在 maxFE=300 下"主循环零次执行"（`11D-1 = 329 > 300`，
    存下来的是**纯初始种群**、只有 1 个快照、FE=329），**在 maxFE=500 下却能正常跑**
    （329 < 500，只是只剩 ~171 次给搜索）。
    ⇒ 不要照抄旧档的结论：本机 `20目标\PCSAEA`、`20目标\KRVEA` 各 480 个文件就是
    "FE=329、单快照"的废数据，而 FE500 档用原版是有意义的。
    另外 `HES_EA` 的聚类死锁在**原版与 `_N100` 版里是同一段代码**（两文件只差 `InitN` 一行）
    ⇒ 原版同样会卡死，给原版跑长任务必须配 `SLICE_TIMEOUT`（或换 guard 版）。

