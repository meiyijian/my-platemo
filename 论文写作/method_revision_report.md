# 方法章节精简与重构报告

**源文件**：`HPDC-MaOEA.tex`（两栏 elsarticle 版，方法部分第 125–1094 行）
**新文件**：`HPDC-MaOEA_method_revised.tex`（已通过 pdflatex 编译：0 error，0 overfull box，0 undefined reference）
**核对源码**：`REMO_new2_AdaMaO_SDEOnly_UniformMix_Original`（主程序 + `private/` 全部 11 个函数）

---

## Step 1：方法章节诊断表

### 当前规模统计（修改前）

| 项目 | 数量 |
| --- | --- |
| 方法章节行数 | 970 |
| **编号公式（`\label{eq:...}` 个数）** | **48** |
| 其中 `equation` 环境 | 40 |
| 其中 `align` 环境（每个含 2 个编号行） | 4 |
| 未编号 `equation*` | 1 |
| subsection | 5 |
| subsubsection | 7 |
| `\paragraph{}` 小标题 | 11 |
| Algorithm | 3 |
| Proposition / Remark | 1 / 1 |
| 正文散文词数（剔除公式、伪代码、表格、注释） | 约 4557 |

### 诊断表

| 当前 subsection | 当前主要问题 | 是否属于创新 | 建议 | 公式处理 |
| --- | --- | --- | --- | --- |
| III.A Overall Framework | 用 5 个带粗体标题的 enumerate 逐条复述五个步骤，与 Algorithm 1 内容重复；伪代码含 `k_eff`、`Lp`、`continue`、struct 式参数，接近 MATLAB 转写；无流程图 | 否（框架） | 五步压成一段连续散文；伪代码抽象到「Train relation surrogate / Draw mode / DualModeSelection」级别；补图位 | eq:problem **KEEP**；eq:rho **INLINE**（并入 $t=FE/FE_{\max}$ 文字） |
| III.B 引言段 | 用一整段声明「hybrid 不代表统计独立」，又用一段列举「两支的两处实现差异 + 不声称互补性」，防御性表述过密 | 是（动机） | 保留「分辨率而非独立性」一句；删掉逐项列举实现差异的整段 | — |
| III.B.1 Continuous Direction-Based PBI Preference | 最重的一节：3 个 `\paragraph`、11 个编号公式。方向集从非支配集提取 → 归一化 → K-means → 反映射 → 退化证明，被拆成 5 个独立公式；PBI 的 cosine/d1/d2/PBI/倒数变换各占一个编号 | 部分（连续质量信号是创新，K-means 退化是诚实性说明而非创新） | 方向集构造压成一段散文 + 1 个坍缩后的结果公式；PBI 三件套合并为 1 个 `aligned`；退化验证保留数值但不再给推导链公式 | eq:pop / eq:ideal / eq:ndset / eq:ndnorm / eq:direction / eq:kvdegen **DELETE 或 INLINE**；eq:direction-collapsed **KEEP**（改名 eq:direction）；eq:assoc-v **INLINE**；eq:d1+eq:d2+eq:score-cont 前半 **MERGE**；eq:d-collapsed **DELETE**；eq:score-collapsed **KEEP** |
| III.B.2 Anchor-Based Coarse Preference | 术语问题最集中：标题与全节使用 anchor / anchor capacity / anchor-normalised / anchor-dir。继承 REMO 的二值 PBI 划分被重新推导（$\vw$、$\hat d_1$、$\hat d_2$、$g^{\rm bin}$、$\ell$、$r(\delta)$ 六个公式）；$\delta$ 二分搜索的区间、容差、终止条件全写在正文 | 否（GetOutput_PBI 主体继承 REMO；仅「代表解作为参考点」是接口选择） | 全节改称 representative solutions；二值划分压成 1 个公式并引用 REMO；$\delta$ 搜索改为一句话 + 参数表；$k$ 与雷达网格分辨率的耦合保留（消融要用）但改为行内 | eq:anchors **DELETE**（改行内 $\mathcal{R}\subset\mathcal{P}$）；eq:keff **MOVE TO PARAMETER TABLE**（正文行内）；eq:ndiv **INLINE**；eq:anchor-dir / eq:d1hat / eq:d2hat **INLINE**（「以 $\vw_{b(i)}$ 替换 $\vv_{a(i)}$ 按 (3) 构造」）；eq:gbin + eq:label-bin **MERGE**；eq:posrate **MOVE TO PARAMETER TABLE** |
| III.B.3 Stage-Aware Hybrid Stratification | Proposition 只给了跨组结论，缺少「组内仍可区分」这一真正对应设计动机的性质；随后又追加 $\Delta_{01}$、松弛条件、Remark 内 $\alpha_{\rm first}$ 三个公式，理论密度高于机制价值 | 是（核心） | 混合式 + 阶段权重合并为 1 式；正组定义 1 式并顺带定义 $\mathcal{C}_2$；Proposition 改为两条（组内差 = $\alpha_t\Delta S$；跨组 $\alpha_t\le1/2$）；松弛条件与 $\alpha_{\rm first}$ 降为 Remark 内行内 | eq:alpha + eq:fuse **MERGE**；eq:group **KEEP**（扩展为同时定义 $\mathcal{C}_1,\mathcal{C}_2$）；eq:delta01 / eq:relaxed / eq:alphafirst **INLINE**；Proposition 内 `equation*` **改为两条 enumerate 结论** |
| III.C Relation Model Construction | 把 REMO 的实现细节公式化：softmax 输出向量、留出错误率求和式各占一个编号；正文写明 3D/2D/D 层宽、75%/25% 划分、mapminmax、笛卡尔积、子采样目标数 $n_\times$ 的精确公式 | 否（主体继承 REMO） | 只保留关系标签定义与关系得分；网络结构改为「same architecture as REMO」+ 参数表；子采样压成一句 | eq:groups **DELETE**（$\mathcal{C}_1,\mathcal{C}_2$ 已由 eq:group 定义）；eq:pairlabel **KEEP**；eq:netout **INLINE**；eq:perr **INLINE**（记为 $e_r$） |
| III.D 引言段 | 直接把实验结论（400 次运行、5.1 倍、3.1 倍、14.8–46.2 次迭代）写进方法动机段 | 是（动机） | 保留「分数无尺度不变性 → 排序与开销分离」的设计论证，具体数字改为前向引用 Section IV | — |
| III.D.1 Pairwise Relation Score and Candidate Pool | 候选池生成被逐轮公式化（`n_parent`、$\mathcal{Q}^{(\ell)}$、`unique` 并集）；四类比较族单独占一个编号；关系得分放在候选选择节内，与关系模型分离 | 否（内层 GA 沿用 REMO 式代理辅助搜索） | 关系得分移入 III.C；四类族改行内文字；池构造改为一段散文 + Algorithm 2 第 1–7 行 | eq:fourfamilies **INLINE**；eq:relscore **KEEP**（移入 III.C）；eq:relbound **INLINE**（并入 eq:relscore）；eq:nparent **MOVE TO ALGORITHM**；eq:pool **MOVE TO ALGORITHM** |
| III.D.2 Relation-Guided Exploratory Mode | 结构基本合理，但 $u(\vx)$ 与 $a^{\rm E}$ 分列两式；$\lambda_t$ 中硬编码 0.45；贪心式中硬编码 0.75/0.25 | 是（核心） | $U$ 与 $A_{\rm exp}$ 合并为一个 `aligned`；0.45 抽象为 $e_{\max}$；0.75/0.25 抽象为 $w,1-w$ | eq:ambiguity + eq:expscore **MERGE**；eq:lambda **KEEP**（常数移表）；eq:prefilter-exp **KEEP**；eq:greedy **KEEP**（权重移表） |
| III.D.3 Indicator-Guided Mode | 重新叙述 PIEA/SDE 的实现：17 个 $L_p$ 候选、箱线图因子 1.5、$\delta_i$ 的 shifted 最近邻公式、[0,3] 缩放、$10^{-4}$ 退化阈值、tanh 变换、30%/20 个/70% 分位点 | 部分（「关系粗筛 + 指标重排」的两段式是创新；SDE 与形状估计是继承） | 前沿形状估计与 SDE 各压成一句并引用 PIEA/SDE；只保留抽象指标代理式；两段式顺序的理由保留 | eq:sde **CITE**（删公式，引用 ref:sde/ref:piea）；eq:svr **KEEP**（改为抽象 $\widehat I(\vx)=\mathcal{M}_I(\vx;\mathcal{D})$）；30%/70% **MOVE TO PARAMETER TABLE**（记为 $q_{\rm rel},q_{\rm ind}$） |
| III.D.4 Mixed-Mode Allocation | 标题「Mixed-Mode Allocation」偏向融合含义；正文强调随机流与种子的工程实现 | 是（但机制极简） | 改标题为 Probabilistic Mode Switching；显式否定 ensemble / adaptive routing；随机流压成半句 | eq:mode **KEEP**；eq:batch **KEEP**（并修正，见下） |
| III.E Computational Complexity | 把 K-means 的 $R=5$ replicates、$I=100$ 迭代上限写进复杂度式，读起来像实现说明 | 否 | 两段保留，删去具体 replicate/iteration 常数，保留「可移除的实现开销」这一判断 | 无编号公式（原本也没有） |

---

## Step 2：新的方法章节目录

```
III. The Proposed HPDC-MaOEA                     ← 开篇即点明两条创新主线
  A. Overall Framework                            ← 1 段散文 + Algorithm 1 + 图位
  B. Hybrid PBI Quality Stratification            ← 创新 1
     B.1 Continuous Directional Preference
     B.2 Representative-Solution-Guided Coarse Preference
     B.3 Hybrid Quality Score and Grouping
  C. Relation Learning on the Hybrid Groups       ← 继承组件，只写接口
  D. Dual-Mode Candidate Selection                ← 创新 2
     D.1 Exploration-Oriented Mode
     D.2 Indicator-Oriented Mode
     D.3 Probabilistic Mode Switching
  E. Computational Complexity
```

**结构变更说明**

| 变更 | 内容 | 理由 |
| --- | --- | --- |
| 合并 | 原 III.D.1「Pairwise Relation Score and Candidate Pool」被拆开：关系得分并入 III.C（它是关系模型的输出），候选池构造并入 III.D 引言段 + Algorithm 2 | 关系得分属于关系模型而非候选选择；池构造是流程不是机制。合并后 III.D 三个子节恰好对应「两个模式 + 切换」，与创新 2 的叙述一致 |
| 更名 | III.B.2「Anchor-Based Coarse Preference」→「Representative-Solution-Guided Coarse Preference」 | 全文取消 anchor 概念（详见 Step 5 术语表） |
| 更名 | III.B.3「Stage-Aware Hybrid Stratification」→「Hybrid Quality Score and Grouping」 | 标题直接说明本节产出物（score → grouping），并与「不优化 $H_i$」的定位一致 |
| 更名 | III.C「Relation Model Construction」→「Relation Learning on the Hybrid Groups」 | 标题即声明本节是接口而非新模型 |
| 更名 | III.D.2「Relation-Guided Exploratory Mode」→「Exploration-Oriented Mode」；III.D.3「Indicator-Guided Mode」→「Indicator-Oriented Mode」 | 与 Contribution 2 的措辞（indicator-oriented / exploration-oriented）统一 |
| 更名 | III.D.4「Mixed-Mode Allocation」→「Probabilistic Mode Switching」 | 「Mixed」易被读成数值融合；实际是固定概率二选一 |
| 更名 | III.B「Hybrid PBI-Based Quality Stratification」→「Hybrid PBI Quality Stratification」；III.B.1 去掉「Direction-Based」 | 与贡献名称逐字一致，减少同义变体 |
| 删除 | 全部 11 个 `\paragraph{}` 小标题 | 三级标题下再套 `\paragraph` 使 III.B.1 出现四层结构；改为段落自然衔接 |
| 删除 | Algorithm 2「Hybrid PBI quality stratification」 | 其 8 行内容与 III.B 正文一一重复；已折叠为 Algorithm 1 中 `Stratify` 一行 |
| 新增 | Algorithm 1 前的 `figure*` 图位（注释状态 + TODO） | 用户要求总体流程图；以注释形式给出，避免缺图导致编译失败 |
| 新增 | Table 1 分为上下两块 | 上块 = 两条创新的参数；下块 = 继承组件的设置。视觉上直接区分「本文创新」与「继承组件」 |

---

## Step 3：公式精简清单（逐个 48 → 17）

`OLD` 为原文标签，`NEW` 为新文件中的编号。

| # | OLD 标签 | 内容 | 处理 | 去向 |
| --- | --- | --- | --- | --- |
| 1 | eq:problem | 昂贵多目标问题定义 | **保留** | NEW (1) |
| 2 | eq:rho | $\rho=\min(1,FE/B)$ | **行内** | 正文 $t=FE/FE_{\max}\in[0,1]$ |
| 3 | eq:pop | $\mathcal{P}=\{\vx_i,\vf_i\}$ | **行内** | III.B 记号段 |
| 4 | eq:ideal | $\vz^{*}=\min_i\vf_i$ | **行内** | III.B 记号段 |
| 5 | eq:ndset | 非支配前沿集合 | **删除** | 散文「the first nondominated front」 |
| 6 | eq:ndnorm | 前沿归一化到单位盒 | **删除** | 散文「mapped to the unit box」 |
| 7 | eq:direction | K-means 中心反映射 + 单位化 | **删除** | 散文一句；结果由 NEW (2) 给出 |
| 8 | eq:kvdegen | $K_v=\min(N_v,n_{\rm ND})=n_{\rm ND}$ | **删除** | 散文「the number of clusters equals the number of nondominated solutions」 |
| 9 | eq:direction-collapsed | 坍缩后的方向集 = 非支配前沿径向单位方向 | **保留**（改名 eq:direction） | NEW (2) |
| 10 | eq:assoc-v | cosine 最大关联 $a(i)$ | **行内** | III.B.1 |
| 11 | eq:d1 | $d_1$ | **合并** | NEW (3) 第 1 行 |
| 12 | eq:d2 | $d_2$ | **合并** | NEW (3) 第 2 行 |
| 13 | eq:score-cont（前半 $g^{\rm con}$） | PBI 值 | **合并** | NEW (3) 第 3 行 |
| 14 | eq:score-cont（后半 $s_i$） | 倒数变换 | **保留**（独立） | NEW (4) |
| 15 | eq:d-collapsed | 坍缩后的 $d_1,d_2$ | **删除** | 直接给 NEW (5) 结果 |
| 16 | eq:score-collapsed | 坍缩后的 $S_i$ 闭式 | **保留** | NEW (5)（Remark 1 内） |
| 17 | eq:anchors | $\mathcal{R}=\{\vr_j\}_{j=1}^{k_{\rm eff}}$ | **删除** | 行内 $\mathcal{R}\subset\mathcal{P}$ |
| 18 | eq:keff | $k_{\rm eff}=\min(N_p,\max(6,\lceil1.5M\rceil))$ | **移入参数表**（正文行内保留） | Table 1 + III.B.2 行内 |
| 19 | eq:ndiv | $n_{\rm div}=\lceil\sqrt{k_{\rm eff}}\rceil$ | **行内** | III.B.2 |
| 20 | eq:anchor-dir | 代表解方向 $\vw_{b(i)}$ | **行内** | III.B.2 |
| 21 | eq:d1hat | $\hat d_1$ | **行内** | 「formed as in (3) with $\vv_{a(i)}$ replaced by $\vw_{b(i)}$」 |
| 22 | eq:d2hat | $\hat d_2$ | **行内** | 同上 |
| 23 | eq:gbin | 归一化后的二值 PBI 值 | **合并** | NEW (6) 分式内 |
| 24 | eq:label-bin | 二值标签 $\ell_i$ | **合并 + 保留** | NEW (6)（记为 $L_i$） |
| 25 | eq:posrate | 正标签比例 $r(\delta)$ | **移入参数表** | Table 1「target positive rate $[0.3,0.7]$」 |
| 26 | eq:alpha | $\alpha=1-\rho$ | **合并** | NEW (7) 右半 |
| 27 | eq:fuse | $h_i=\alpha s_i+(1-\alpha)\ell_i$ | **合并 + 保留** | NEW (7)（记为 $H_i=\alpha_tS_i+(1-\alpha_t)L_i$） |
| 28 | eq:group | 正组 $c_i$ 的 cases 定义 | **保留**（扩展） | NEW (8)，同时定义 $\mathcal{C}_1,\mathcal{C}_2$ |
| 29 | eq:delta01 | 跨类跨度 $\Delta_{01}$ | **行内** | Remark 2 |
| 30 | eq:relaxed | 松弛条件 $\alpha<1/(1+\Delta_{01})$ | **行内** | Remark 2 |
| 31 | eq:alphafirst | $\alpha_{\rm first}=1-N_{\rm init}/B$ | **行内** | Remark 2 |
| 32 | eq:groups | $\mathcal{C}_1,\mathcal{C}_2$ 定义 | **删除** | 已由 NEW (8) 给出 |
| 33 | eq:pairlabel | 关系标签 $y_{ij}$ | **保留** | NEW (9) |
| 34 | eq:netout | softmax 输出向量 | **行内** | III.C |
| 35 | eq:perr | 留出错误率求和式 | **行内** | 记为 $e_r$ |
| 36 | eq:fourfamilies | 四类比较族 | **行内** | III.C |
| 37 | eq:relscore | 关系得分 $r(\vx)$ | **保留** | NEW (10)（记为 $R(\vx)$） |
| 38 | eq:relbound | $-4\le r(\vx)\le4$ | **行内** | 并入 NEW (10) 末尾 |
| 39 | eq:nparent | $n_{\rm parent}$ | **移入伪代码** | Algorithm 2 第 4 行 |
| 40 | eq:pool | 池的并集去重 | **移入伪代码** | Algorithm 2 第 2–7 行 |
| 41 | eq:ambiguity | 预测模糊度 $u(\vx)$ | **合并** | NEW (11) 第 1 行（记为 $U(\vx)$） |
| 42 | eq:expscore | $a^{\rm E}=\tilde r+\lambda_t\tilde u$ | **合并 + 保留** | NEW (11) 第 2 行（记为 $A_{\rm exp}$） |
| 43 | eq:lambda | $\lambda_t$ 两因子式 | **保留**（0.45 抽象为 $e_{\max}$） | NEW (12) |
| 44 | eq:prefilter-exp | 分位点保留集 | **保留** | NEW (13) |
| 45 | eq:greedy | 贪心批式 + 最小距离 | **保留**（0.75/0.25 抽象为 $w$） | NEW (14) |
| 46 | eq:sde | SDE 移位最近邻距离 | **改为引用** | 引用 ref:sde + ref:piea，正文一句 |
| 47 | eq:svr | $\widehat\phi=\mathrm{SVR}(\vx;\mathcal{P},\bm{\phi})$ | **保留**（改为抽象形式） | NEW (15) $\widehat I(\vx)=\mathcal{M}_I(\vx;\mathcal{D})$ |
| 48 | eq:mode | 模式抽取 cases | **保留** | NEW (16) |
| 49 | eq:batch | $n_t$ 上下界 | **保留 + 修正** | NEW (17)，见「准确性修正」 |

新增编号：无（17 个全部由原有公式保留或合并而来）。

**新文件公式清单（17 个）**

| NEW | 标签 | 内容 | 归属 |
| --- | --- | --- | --- |
| (1) | eq:problem | 问题定义 | preliminaries |
| (2) | eq:direction | 种群自适应方向集 | 创新 1 |
| (3) | eq:pbi | $d_1,d_2,g^{\rm PBI}$（`aligned`） | 继承（PBI） |
| (4) | eq:score-cont | 连续质量得分 $S_i$ | 创新 1 |
| (5) | eq:score-collapsed | $S_i$ 在非支配集上的闭式 | 创新 1（诚实性） |
| (6) | eq:label-bin | 代表解引导的二值标签 $L_i$ | 继承（REMO） |
| (7) | eq:fuse | 混合质量得分 $H_i$ + $\alpha_t$ | **创新 1 核心** |
| (8) | eq:group | 正组 / 非正组 | **创新 1 核心** |
| (9) | eq:pairlabel | 关系标签 $y_{ij}$ | 继承（REMO） |
| (10) | eq:relscore | 关系得分 $R(\vx)$ | 继承（REMO） |
| (11) | eq:expscore | $U(\vx)$ + $A_{\rm exp}(\vx)$（`aligned`） | **创新 2 核心** |
| (12) | eq:lambda | 阶段/误差系数 $\lambda_t$ | 创新 2 |
| (13) | eq:prefilter-exp | 分位点保留集 | 创新 2 |
| (14) | eq:greedy | 质量–多样性批采集 | 创新 2 |
| (15) | eq:svr | 抽象指标代理 $\widehat I$ | 创新 2 |
| (16) | eq:mode | 概率式模式切换 | **创新 2 核心** |
| (17) | eq:batch | 批量上界 | 创新 2 |

按用户建议的层级核对：preliminaries 1（建议 0–1）✓；Hybrid PBI 6，即 (2)(3)(4)(5)(7)(8)（建议 4–6，多出 1 个是 (5) 的诚实性闭式）；relation learning 2，即 (9)(10)（建议 1–2）✓；candidate selection 7，即 (11)–(17)（建议 4–6，多出 1 个是 (13)，因 (17) 需引用它）；complexity 0（建议 0–2）✓。

---

## Step 4：修改后的规模对照

### Before → After

| 指标 | 修改前 | 修改后 | 变化 |
| --- | --- | --- | --- |
| **编号公式** | **48** | **17** | **−64.6%** |
| 方法章节行数 | 970 | 689 | −29.0% |
| 正文散文词数 | 约 4557 | 约 3639 | −20.1% |
| subsection | 5 | 5 | 不变 |
| subsubsection | 7 | 6 | −1 |
| `\paragraph{}` 小标题 | 11 | 0 | −11 |
| Algorithm | 3 | 2 | −1 |
| Proposition | 1（1 条结论） | 1（2 条结论） | 结论 +1，环境不变 |
| Remark | 1 | 2 | +1（原 III.B.1 的坍缩说明升格为 Remark 1） |
| 参数表 | 1（11 行，平铺） | 1（14+7 行，创新/继承分块） | 结构化 |
| 图位 | 0 | 1（注释 + TODO） | +1 |

公式减少 64.6%，超过用户要求的 40%–60%，并落在建议的 15–22 区间内。

---

### 删除了什么

1. **方向集构造链（4 个公式）**：非支配集合、单位盒归一化、K-means 中心反映射、簇数退化等式。结论式 NEW (2) 保留，推导链改为一句散文。
2. **坍缩后的 $d_1,d_2$ 中间式**：直接给 $S_i$ 的闭式 NEW (5)。
3. **代表解集合的集合式定义**、**$\hat d_1,\hat d_2$ 两式**、**$\mathcal{C}_1,\mathcal{C}_2$ 的重复定义**（已由 NEW (8) 给出）。
4. **softmax 输出向量式**与**留出错误率的求和式**：改为行内并统一记为 $e_r$。
5. **四类比较族的集合式**、**$n_{\rm parent}$**、**候选池并集式**。
6. **SDE 移位最近邻公式**：改为引用。
7. **Algorithm 2（Hybrid PBI stratification 伪代码）**：8 行内容与 III.B 正文重复。
8. **全部 11 个 `\paragraph{}` 小标题**。
9. **III.B 引言中逐项列举「两支的两处实现差异」的整段**：保留「hybrid 指分辨率不指独立性」一句，删去方向来源与归一化原点的逐项对照（该信息在 III.B.1/B.2 各自的坐标约定说明中已有）。
10. **III.D 引言中的实验数字**（400 次运行、5.1 倍、3.1 倍、14.8–46.2 次迭代）：改为前向引用 Section IV.D。
11. **III.B.1 末尾的 TODO 审计字段清单**（DirectionSource / ClusterCount 等导出项）：属工作笔记。
12. **复杂度分析中的 K-means replicate / 迭代上限常数**。

### 合并了什么

| 合并后 | 由哪些原公式合并 |
| --- | --- |
| NEW (3) `aligned` | eq:d1 + eq:d2 + eq:score-cont 前半（$g^{\rm con}$） |
| NEW (6) | eq:gbin + eq:label-bin |
| NEW (7) | eq:alpha + eq:fuse |
| NEW (8) | eq:group + eq:groups（同时定义 $\mathcal{C}_1,\mathcal{C}_2$） |
| NEW (10) | eq:relscore + eq:relbound（界写入同一行末） |
| NEW (11) `aligned` | eq:ambiguity + eq:expscore |
| Proposition 1 | 原 Proposition（跨组）+ 新增组内性质，两条 enumerate 共用一个证明 |
| Remark 2 | 原 Remark + eq:delta01 + eq:relaxed + eq:alphafirst |

### 哪些 trick 被隐藏

以下实现细节已从正文移除或降级，**算法逻辑未改动**：

- $\delta$ 二分搜索的区间 $[-20,20]$、容差 $10^{-1}$、目标比例 $[0.3,0.7]$ → 参数表（正文只说「bounded bisection ... stops as soon as the positive rate enters a tolerant interval」）。
- 关系网络三层宽度 $3D,2D,D$、75%/25% 划分、`mapminmax`、one-hot 编码、`combvec` 笛卡尔积、子采样目标数 $n_\times$ 的精确表达式 → 参数表 + 「same architecture as REMO」。
- 前沿形状估计的 17 个 $L_p$ 候选、箱线图因子 1.5、少于 20 解时 $L_p=1$ → 参数表 + 一句引用。
- SDE 的 $[0,3]$ 缩放、$10^{-4}$ 退化阈值、`tansig` 变换 → 一句「solutions whose density value is numerically indiscriminable fall back to a convergence measure」。
- 指标模式的「至少 20 个候选」下限 → 参数表 $q_{\rm rel}$ 行的括注。
- K-means 的 `Replicates=5`、`MaxIter=100`、`EmptyAction='singleton'` → 删除（保留「the clustering call is retained for random-stream compatibility」这一必要说明）。
- 随机流的种子构造（`10000000+runId`）、`CreateSDECandidateModeStream` 的函数名 → 一句「a stream seeded from the run index and independent of the stream that drives variation and subsampling」。
- `try/catch` 回退、空池回退、`eps`、`unique(...,'stable')`、参数校验 → 仅保留两处对结果有语义影响的回退（指标代理不可用时退回关系得分；选择集为空时补 $n_{\min}$ 个后代），其余删除。
- 伪代码中的 MATLAB 痕迹（`continue` 之外的 struct 字段、`k_eff`、`Lp` 传递、`OperatorGA(...)` 调用形式）→ 改为 `Stratify`、`Train relation surrogate`、`offspring of ...` 等论文级动作。

**未隐藏的诚实性说明（有意保留）**：K-means 在本文设置下退化为恒等映射、方向集实为非支配前沿自身的径向方向、连续偏好在非支配集上主要度量收敛性而非前沿位置、$U$ 不是认知不确定性、$R$ 不是 Pareto 胜率、$L_i$ 不等同于真实 Pareto 标签、候选池并非模式无关、决策空间多样性不保证目标空间分散。这些说明与实验代码一致，删去会使正文描述的算法与实际跑过的算法不符。

### 哪些公式因属已有方法而改为引用

| 原公式 | 归属 | 现处理 |
| --- | --- | --- |
| eq:score-cont 的 PBI 部分 | MOEA/D 的 PBI | NEW (3) 保留形式但正文明说「the conventional PBI value~\cite{ref:moead}」 |
| eq:gbin + eq:label-bin 的划分规则 | REMO 的 PBI partition | NEW (6) 保留一式，正文明说「applies the PBI partition of REMO~\cite{ref:remo} with the representatives as reference points」 |
| eq:anchors / eq:keff / eq:ndiv 涉及的代表解选择 | RSEA 的雷达网格选择 | 全部改为散文 + `\cite{ref:rsea}` |
| eq:netout / eq:perr / 网络结构 | REMO 的关系学习 | 「We employ the same relation-learning architecture as REMO」+ 参数表 |
| eq:sde | SDE | 删公式，`\cite{ref:sde}` |
| 前沿形状估计（17 个 $L_p$、箱线图） | PIEA | 一句 + `\cite{ref:piea}` |
| eq:svr 的 RBF-SVR 细节 | 标准 SVR | NEW (15) 抽象为 $\mathcal{M}_I$，核与标准化设置入参数表 |

引用未新增、未伪造：仍为原有 8 条 bibitem，`ref:moead`、`ref:remo`、`ref:rsea`、`ref:piea`、`ref:sde` 在方法部分被实际引用。

### 哪些核心公式被保留

**创新 1**：NEW (2) 种群自适应方向集、(4) 连续质量得分 $S_i$、(7) 混合得分 $H_i$ 与阶段权重 $\alpha_t$、(8) 正组 / 非正组、(5) $S_i$ 闭式（用于说明该信号实际度量什么）。
**创新 2**：NEW (11) 预测模糊度与探索采集式、(12) 阶段/误差系数 $\lambda_t$、(13) 分位点保留集、(14) 质量–多样性批采集、(15) 抽象指标代理、(16) 概率式模式切换、(17) 批量上界。
**Proposition 1(i)**：$L_i=L_j\Rightarrow H_i-H_j=\alpha_t(S_i-S_j)$ —— 直接对应「连续信号在粗标签内部仍提供区分能力」这一设计动机，是本次新增的结论。

### 哪些术语被统一

| 原表述 | 新表述 | 出现处 |
| --- | --- | --- |
| anchor / anchors / anchor set | representative solution(s) / representative set $\mathcal{R}$ | 全节（原方法部分 33 处 anchor 词族，全文现为 0） |
| anchor capacity $k_{\rm eff}$ | number of representative solutions $k$ | 正文 + 参数表 + 消融 TODO |
| anchor-based binary preference | representative-solution-guided coarse preference | III.B.2 标题与正文 |
| anchor-normalised PBI value | PBI value normalised by the associated representative | III.B.2 |
| anchor-based boundary | representative-based boundary | 结论 TODO |
| K-means adaptive reference vectors / clustering-based direction generation | population-adaptive direction set；「we do not present clustering as a mechanism of the algorithm」 | III.B.1（clustering 一词仅在说明退化与实现开销时出现 4 次，均非机制主张） |
| uncertainty / classification ambiguity | prediction ambiguity $U(\vx)$ | III.D.1（保留一处否定式「not a calibrated variance or an epistemic uncertainty」） |
| Mixed-Mode Allocation / mixing probability | probabilistic mode switching / stochastic dual-mode selection | III.D.3（并显式否定 ensemble、adaptive routing） |
| exploratory mode / indicator-guided mode | exploration-oriented mode / indicator-oriented mode | III.D |
| fused sorting score $h_i$ | hybrid quality score $H_i$ | III.B.3 |
| continuous score $s_i$ / binary preference $\ell_i$ | continuous quality score $S_i$ / coarse label $L_i$ | III.B |
| progress $\rho$ / budget $B$ | $t=FE/FE_{\max}$ | 全节 |
| held-out pairwise error $p_{\rm err}$ | $e_r$ | III.C、III.D.1 |
| positive group / non-positive group | 保持不变（已符合建议） | — |

强度表述核查：全节未出现 guarantees、ensures、corrects erroneous labels、optimal balance、robustly improves 等超出证据的措辞。III.B.3 写作「inside one coarse label the continuous preference still discriminates」而非「corrects inaccurate PBI labels」；III.D 写作「provide two alternative criteria for allocating expensive evaluations」并显式声明「we do not claim that drawing between them attains an optimal exploration--exploitation balance」。

---

## 一处准确性修正（对源码的重新核对）

原稿 eq:batch 写作
$$n_t=\min[n_{\max},\max(n_{\min},|\mathcal{H}^{m_t}|)],$$
并在正文称 $[n_{\min},n_{\max}]$ 是批量区间。核对 `AdaMaOSelection.m` 后发现两个分支都在该式之后紧接一行
```matlab
n_eval = min(n_max,max(n_min,numel(cand_idx)));
n_eval = min(n_eval,numel(cand_idx));     % ← 第二次截断
```
两行复合后恒等于 `min(n_max, numel(cand_idx))`：当候选数少于 $n_{\min}$ 时，`max` 抬升的值会被第二行压回候选数，因此 $n_{\min}$ **不是批量下界**。它的真实作用在上一步——当分位点筛出的候选不足 $n_{\min}$ 时，保留集被补齐到 $n_{\min}$ 个（`select_explore` 与 `select_indicator` 中的 `if numel(cand_idx) < n_min` 分支）。

新文件因此把 NEW (17) 改为 $n_b=\min(n_{\max},|\mathcal{H}^{m}|)$，并在正文说明 $n_{\min}$ 作用于保留集而非批量；参数表也相应拆成两行（$n_{\min}$ = minimum size of the retained set，$n_{\max}$ = maximum size of the batch）。算法逻辑未改动，只是描述与源码对齐。

---

## 编译与文件状态

| 文件 | 状态 |
| --- | --- |
| `HPDC-MaOEA.tex` | **未改动**（原稿保留） |
| `HPDC-MaOEA_singlecol_backup.tex` | 未改动 |
| `HPDC-MaOEA_method_revised.tex` | 新增，pdflatex 三次编译通过：7 页，0 error，0 overfull box，0 undefined reference |
| `method_revision_report.md` | 本报告 |

保持不变的部分：documentclass 与全部宏包、`thebibliography` 的 8 条 bibitem 与引用风格、frontmatter、Section I/II/IV/V 的占位与实验数字、Table 1 的 `table*` 跨栏形式。preamble 仅两处改动：更新文件头注释、删除已无引用的 `\keff` 宏。

### 待办

1. 导出总体流程图为 `fig_framework.pdf`，取消 III.A 中 `figure*` 块的注释。
2. Section IV.C 的消融 TODO 已改为「continuous preference only / coarse preference only / full hybrid」并要求区分「代表解个数 $k$」与「雷达网格分辨率 $\lceil\sqrt{k}\rceil$」，与 III.B.2 的耦合说明对应。
3. Section IV.D 的 TODO 已成为 III.D 引言中数字的落点，撰写时需覆盖两个前向引用：cutoff 审计的 5.1 倍 / 3.1 倍变异，以及两模式各自的批次分散度。
4. Remark 1、Remark 2 中目前使用的是合成前沿验证值（$2\times10^{-16}$、$0.035$–$0.172$）。正式协议（$M\in\{3,5,10,20\}$、$D=30$、$N=100$、$FE_{\max}=500$）下的真实运行日志导出后应替换，Section IV.D 的 TODO 已列出所需字段。
