import { Aside, Section, Subsection, Table } from "reacticle";
import { DiagnosticBoundaries } from "../raw-blocks/06-diagnostic-boundaries";

export function SectionDiagnostics() {
  return (
    <Section index="06" title="为什么要改：两个诊断把问题具体化">
      <p>
        当前机制不是从“高维一定更难”这一泛化口号出发，而是由两类可测问题推动。第一类发生在标签评价层：很多目标下，严格或 ε-支配很难提供足够的成对外部真值。第二类发生在候选选择层：当前 indicator 级联的关系粗筛会遗漏一部分从真实 PF 参考集看仍有价值的候选。
      </p>

      <DiagnosticBoundaries />

      <Subsection index="6.1" title="诊断 A：支配型外部真值失去可测性">
        <p>
          ConfidenceProbe v1 原本想回答“内部置信分数越高，关系预测是否越接近外部真值”。协议使用严格 Pareto 支配作为真值，但在 M=10/20 的若干问题上几乎没有可比关系对，最终正确地给出 <code>INSUFFICIENT_DATA</code>。这个负结果首先说明测量设计失效，而不是算法标签已经被证明错误。
        </p>
        <Table
          caption="ConfidenceProbe v1 中最关键的可比性结果"
          columns={[
            { key: "setting", label: "设置", width: "31%" },
            { key: "strict", label: "严格支配" },
            { key: "epsilon", label: "ε-支配补充" },
          ]}
          rows={[
            { setting: "M=10，WFG3 / WFG7", strict: "约 20.1 万个 good-rest 对中可比对为 0", epsilon: "WFG7，ε=0.10：1693/201000（0.8%）" },
            { setting: "M=20，DTLZ7 / WFG3 / WFG7", strict: "可比对均为 0", epsilon: "WFG7，ε=0.10：1070/201000（0.5%）" },
            { setting: "M=20，DTLZ2", strict: "仅 44 对", epsilon: "仍不足以代表完整候选关系分布" },
          ]}
          source="ConfidenceProbe v1，两个 profile 均判 INSUFFICIENT_DATA；数字用于说明真值稀疏。"
        />
        <Aside tone="principle" label="正确推论">
          M≥10 时，以支配关系检验标签外部效用会遇到严重样本稀疏，因此 Stage 3 改用基于真实 PF 参考集的 IGD+ 贪心效用、留一边际贡献和未来生存。它不等于“关系监督本身没了”。
        </Aside>
      </Subsection>

      <Subsection index="6.2" title="诊断 B：当前 indicator 级联存在覆盖缺口">
        <p>
          CascadeAudit pilot 对当前 indicator 路径做候选级反事实审计：先看关系得分 top-30% 能覆盖多少 oracle-useful 候选，再看被拒绝集合中是否存在理论可救的解。设置为 6 个问题、M=10、2 runs、maxFE=300、gmax=500，三个进度检查点，并在参考集灵敏度失败后按预注册改用完整 <code>GetOptimum(10000)</code> 参考集重跑。
        </p>
        <Table
          caption="H1 只回答“覆盖缺口是否存在”"
          columns={[
            { key: "metric", label: "指标", width: "18rem" },
            { key: "value", label: "结果", width: "12rem" },
            { key: "meaning", label: "含义" },
          ]}
          rows={[
            { metric: "MeanNormalizedBatchCoverageRegret", value: "0.253", meaning: "6 个问题中 5 个大于 0。" },
            { metric: "MeanRecall@K", value: "0.444", meaning: "关系粗筛平均命中不到一半 oracle Top-K；WFG4/6 为 0.25–0.31。" },
            { metric: "OracleRescue MeanCapture", value: "0.917", meaning: "被拒绝集合内确实存在大量 oracle-useful 候选，说明有理论救援上限。" },
          ]}
          source="CascadeAudit pilot：12 个 problem-run，方向性证据，不是正式统计结论。"
        />
        <p>
          这项诊断针对的是当前 AdaMaO indicator 分支中的 top-30% 级联。原始 REMO 使用关系投票与 <code>score&gt;3.9</code>，因此不能把这组数字改写成“REMO 本身具有同样的 top-30% 盲区”。更重要的是，发现可救候选不等于已经找到有效的救援信号。
        </p>
      </Subsection>
    </Section>
  );
}
