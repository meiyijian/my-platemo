# Source extraction and scientific audit notes

## 抽取说明

- 输入：`组会汇报稿_UniformMix_Original.md`，Markdown，中文。
- 方法：Beautiful Article 的轻量 Markdown 提取脚本；保持原有 601 行标题、表格、公式、代码块与附录结构。
- 完整性：源文件与 `source.md` 的逐行文本一致；字符数差异仅来自 LF 转为 CRLF。
- 翻译：不需要；最终文章继续使用中文。
- 原稿处理：原文件保持不变。HTML 将基于审校后的叙事重组，不会把修改反写到原稿。
- 图片：原稿只有配图建议，没有嵌入图片。已发现可用的本地机制图 `科研架构图/混合PBI_cycle1.png`；`混合PBI_cycle1_full.png` 含编辑器界面，不宜用于正式报告。

## 对照过的事实底座

- 当前入口：`REMO_new2_AdaMaO_SDEOnly_UniformMix_Original.m`。
- 当前标签与候选选择：`private/HybridPBI_Classification.m`、`private/AdaMaOSelection.m`。
- REMO 基线：`../REMO/REMO.m`、`../REMO/RSurrogateAssistedSelection.m`、`../REMO/GetOutput_PBI.m`。
- Cascade pilot：`../REMO_new2_AdaMaO_SDEOnly/notes/2026-08-06-cascade-pilot-conclusion.md`。
- ConfidenceProbe：`Experiments/REMO_new2_AdaMaO_ConfidenceProbe/CONCLUSIONS.md`。
- 标签验证：`Experiments/REMO_new2_AdaMaO_UniformMix_LabelValidation/` 下 5 份计划，共 1942 个物理行；这些是计划，不是已完成结果。
- PC-SAEA 本地实现：`../PC-SAEA/PCSAEA.m`、`../PC-SAEA/CalFitnessPC.m`。
- 论文出处：REMO，IEEE TEVC 26(5), 1157–1170, 2022，DOI `10.1109/TEVC.2022.3152582`；PC-SAEA，Swarm and Evolutionary Computation 80, 101323, 2023，DOI `10.1016/j.swevo.2023.101323`。

## 审校结论

原稿的结构、负结果意识和五阶段验证计划是合理的，但当前版本不能原样发布。核心问题不是数字抄错，而是若干结论超出了试验和当前代码能够支持的边界。

| 原稿位置 | 风险 | 审校后的处理 |
|---|---|---|
| 第 1 页 | “分类比回归容易、且与目标数解耦”“这就是能上 TEVC 的原因”属于无证据的因果归因。 | 改为“关系模型输出维数不随目标数线性增加，但标签构造仍受 M 影响”；删除发表原因推测。 |
| 第 2 页 | ConfidenceProbe v1 证明的是严格/ε-支配作为外部真值在 M≥10 时缺少可比样本，不等于 REMO 的 PBI 监督消失，更不能推出 6 个锚点造成大面积误标。 | 标题改为“支配型外部真值失去可测性”；把它作为独立效用验证的动机，不作为标签错误的证明。 |
| 第 3 页 | top-30% 粗筛属于当前 AdaMaO indicator 分支，原始 REMO 使用关系投票和 `score>3.9`，因此不能写成“REMO 自身选择机制”。 | 改为“当前 indicator 级联的候选覆盖审计”；明确 6 问题、M=10、2 runs、FE=300 仅是方向性 pilot。 |
| 第 3 页与附录 Q9 | 12-run pilot 不能单独支撑“一篇诊断论文”或新颖性结论。 | 改为“提供值得扩大验证的诊断线索”；是否成文取决于扩展问题池、M 档位和重复数后的稳定性。 |
| 第 4 页 | “逐行一致”过强；当前副本加入了空输入、NaN/Inf 等防御性处理。 | 改为“采样、标签、划分和普通无权训练逻辑保持算法等价，除防御性保护外”。 |
| 第 5 页 | 增大 `k_eff`、K-means 方向与阶段融合是已实现设计，但尚未证明更准确或更有外部效用。 | 保留机制，明确它们是待验证假设；不再说“直接回应/解决覆盖坍缩”。 |
| 第 6 页 | 五阶段方案合理，但尚未实现或执行；“5×2×5=100”算式少了一维。 | 明确“已成文、未执行”；100 个作业来自 2 个行为版本 × 5 问题 × 2 个 M × 5 runs。 |
| 第 7 页 | 双代理和两种模式的代码描述基本正确；`uncertainty` 不是校准不确定性。 | 保留实现说明，统一称“softmax 预测模糊度”；第二代理称“SDE 风格指标 SVR”，避免扩大来源归属。 |
| 第 8 页 | pilot 只否决了特定 indicator-rescue 与所测门控，不能证明所有在线仲裁信号不存在、固定日程必然过拟合或 p=0.5 具有极小极大最优性。 | 将 p=0.5 定位为“无可靠仲裁证据时的中性对照/工程性对冲”，其合理性需与 AlwaysExplore、AlwaysIndicator、LinearSchedule 做配对验证。 |
| 第 9 页 | 当前 OriginalRelation 主程序不使用 PBI `confidence`、网络置信度或 `degeneracy`，没有“主信号 + 回退”架构。 | 移到附录“历史诊断与未实现方向”；保留 WFG3 现象，但注明 SDE 真值同源、问题池仅 5 个，几何归因未经机理实验。 |
| 第 10 页 | 表中结果来自上一版 AdaMaO，不能证明当前简化版“没有破坏搜索能力”。 | 降级为历史背景；当前版本正式结论必须重跑配对种子并报告 IGD/IGD+/HV。FE=300 只作开发筛查，FE=500 才进入正式链条。 |
| 第 11 页 | 两项实现风险判断有价值；但“这不是 bug”过早，完成时间也没有测量依据。 | 改为“当前实现选择、正确性未验证”；删除半天到一天的工期承诺。 |
| 第 12 页 | “200-run 校准 + 已知边界 + 回退架构”与当前实现不符；对 REMO/PC-SAEA 的“只有我知道”“拍脑袋”属于未支持的新颖性和贬损性表述。 | 改成证据状态表，不把历史诊断写成当前贡献；PC-SAEA 只按论文公开的验证可靠性、直接/反向/忽略模型管理来描述。 |
| 附录 Q5/Q7 | Q5 把 PBI 置信度分箱单调性错误迁移到候选分位阈值；Q7 句子在 `1 −` 处被截断。 | 删除 Q5 的错误支撑；补全 Q7 为“1−|score_v−label_dyn|，是同源表征一致性分数，不是概率，且当前主程序未使用”。 |
| 全文时长 | 12 页建议时间相加约 31 分钟，与“25 分钟正文”冲突。 | HTML 采用完整报告结构；另给出约 22–25 分钟的主线阅读/讲述顺序，细节放附录。 |

## 可直接保留的强项

- 主动报告 `INSUFFICIENT_DATA`、H2/H4 FAIL 和负净增益，没有把失败包装成成功。
- 明确 HybridPBI 最终仍硬化为 Top-rGood `Catalog`，普通无权关系训练不构成连续监督。
- 五阶段链条把机制存在性、标签消融、独立 IGD+ 效用、solution-disjoint 泛化和端到端效果分开，并设置停止条件。
- 两项实现风险（连续项可能空转、K-means 分支可能少触发）来自真实源码，且足以改变论文主张，应该前置验证。

## 待用户确认

- HTML 的文章类型、主题、宽度、外部图片模式和封面开关。
- 默认按“证据安全修订版”生成；不把上述高风险原句原样保留。
