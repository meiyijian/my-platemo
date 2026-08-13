import { ActionList, Aside, RiskList, Section, Subsection, Table } from "reacticle";
import { ValidationGates } from "../raw-blocks/09-validation-gates";

export function SectionValidationRoadmap() {
  return (
    <Section index="09" title="下一步：五阶段验证与六周执行">
      <p>
        当前最重要的不是再加模块，而是把“机制存在 → 标签有效 → 模型可迁移 → 候选选择改善 → 端到端性能”逐级连起来。五份验证计划已经成文，但尚未实现为完整 MATLAB 实验；因此这里呈现的是预注册路线，而不是已完成结果。
      </p>

      <ValidationGates />

      <Subsection index="9.1" title="每个阶段回答一个不可替代的问题">
        <Table
          caption="五阶段验证链"
          columns={[
            { key: "stage", label: "阶段", width: "9rem" },
            { key: "question", label: "核心问题", width: "31%" },
            { key: "design", label: "关键设计" },
            { key: "stop", label: "停止条件", width: "20%" },
          ]}
          rows={[
            { stage: "S1 机制审计", question: "连续项、K-means 方向与 α 调度是否真的参与？", design: "只记录快照，不改轨迹；与冻结算法逐值等价；AnchorNative 同运行时基线。", stop: "机制空转或轨迹不等价。" },
            { stage: "S2 标签消融", question: "方向来源、连续化、正例比例、融合和时间调度谁在起作用？", design: "同一 immutable 快照；含打乱、均匀方向和 k_eff 对照；不新增 FE。", stop: "预设标签结构无法与打乱对照区分，或消融效应方向不稳定。" },
            { stage: "S3 独立效用", question: "标签选择的解是否对真实 PF 更有用？", design: "IGD+ 贪心 Top25、留一边际贡献、未来生存；run-cluster bootstrap 与多重校正。", stop: "无独立外部效用或数据不足。" },
            { stage: "S4 隔离泛化", question: "收益能否传到未参与训练的解和真实查询？", design: "E_pair、E_solution、E_query 分开；三折 solution-disjoint。", stop: "LABEL_GAIN_NOT_TRANSFERRED。" },
            { stage: "S5 端到端", question: "标签差异能否在共同候选池和最终指标上兑现？", design: "5A shadow evaluation；5B 只替换标签构造；5-run 筛查后才做 30-run。", stop: "筛查门槛未通过。" },
          ]}
        />
        <Aside tone="principle" label="100 个 screening 作业的正确算式">
          2 个行为版本 × 5 个问题 × 2 个目标数档位 × 5 个 runs = 100。正式设置使用 maxFE=500；WFG3 请求 D=30 时按问题定义实际为 D=31。
        </Aside>
      </Subsection>

      <Subsection index="9.2" title="三项必须先排除的实现风险">
        <RiskList
          risks={[
            {
              name: "α 融合可能空转",
              impact: "high",
              likelihood: "medium",
              mitigation: "记录 score_v 方差、融合前后排名变化及 Catalog 与纯 label_dyn 的重合率；若连续项不改变排序，删除或重标该贡献。",
              owner: "本研究",
              status: "S1 首要问题",
            },
            {
              name: "K-means 方向分支可能很少触发",
              impact: "high",
              likelihood: "medium",
              mitigation: "逐代记录第一前沿规模、分支命中率与回退原因；若绝大多数代回退均匀向量，缩窄“数据自适应方向”主张。",
              owner: "本研究",
              status: "S1 首要问题",
            },
            {
              name: "方向关联与 PBI 投影原点不一致",
              impact: "medium",
              likelihood: "high",
              mitigation: "先在冻结轨迹中记录影响，不静默修正；随后以单因素实现变体比较原始 PopObj 与 PopObj−Zmin 的关联方式。",
              owner: "本研究",
              status: "待机制消融",
            },
          ]}
        />
      </Subsection>

      <Subsection index="9.3" title="六周执行顺序">
        <ActionList
          items={[
            { task: "S1 pilot：score_v 方差、方向分支触发率与冻结轨迹等价", owner: "本研究", due: "第 1 周", status: "待开始" },
            { task: "S1 screening：2 版本 × 5 问题 × 2M × 5 runs", owner: "本研究", due: "第 2 周", status: "门控" },
            { task: "S2 离线标签消融 L0–L8，含打乱与均匀方向对照", owner: "本研究", due: "第 3 周", status: "依赖 S1" },
            { task: "S3 独立 IGD+ 效用与未来结果分析", owner: "本研究", due: "第 4 周", status: "依赖 S2" },
            { task: "S4 solution-disjoint / query-aligned 泛化并同步写稿", owner: "本研究", due: "第 5 周", status: "依赖 S3" },
            { task: "按门槛决定是否启动 S5 与当前版正式 M=10/20 主实验", owner: "本研究", due: "第 6 周", status: "Go / No-Go" },
          ]}
        />
      </Subsection>
    </Section>
  );
}
