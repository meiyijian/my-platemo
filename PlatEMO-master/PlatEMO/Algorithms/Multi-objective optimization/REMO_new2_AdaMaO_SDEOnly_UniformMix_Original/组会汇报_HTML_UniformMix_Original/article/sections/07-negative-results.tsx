import { Aside, Section, Subsection, Table } from "reacticle";
import { StopChain } from "../raw-blocks/07-stop-chain";

export function SectionNegativeResults() {
  return (
    <Section index="07" title="负结果如何改变算法故事">
      <p>
        H1 建立覆盖缺口之后，一个自然机制是“让指标代理把关系粗筛误杀的候选救回来”。CascadeAudit 为此设置了真正的反事实对照：不仅比较指标分歧候选，还从被拒绝集合中选取决策空间多样性匹配的随机候选，防止把单纯的多样性收益误认成指标信息。
      </p>
      <p>
        结果没有支持救援故事。DTLZ 家族中，真实指标分歧相对 DiversityMatchedRandom 的差值为 −0.0048；WFG 家族平均方向为正，但 run 间符号翻转。把基础批次中指标最差的候选固定替换为最大正分歧候选时，平均净增益为 −0.0015，意味着所测救援在固定预算下平均损害 IGD+。
      </p>

      <StopChain />

      <Subsection index="7.1" title="候选级门控同样没有通过">
        <Table
          caption="H4 的判别分数看似可用，但策略结果没有改善"
          columns={[
            { key: "metric", label: "量", width: "20rem" },
            { key: "value", label: "结果", width: "15rem" },
            { key: "reading", label: "解释" },
          ]}
          rows={[
            { metric: "门控 AUROC", value: "0.620 [0.589, 0.656]", reading: "能区分一部分标签，却不足以保证选择收益。" },
            { metric: "GatedNegativeRate", value: "0.371", reading: "高于未门控的 0.361。" },
            { metric: "FavorableProblemFraction", value: "0", reading: "所测问题中没有一个满足预注册有利条件。" },
            { metric: "候选级边际 IGD 关联", value: "约 ±1pp 内", reading: "ConfidenceProbe 未观察到可用的候选价值关联。" },
          ]}
          source="CascadeAudit 与 ConfidenceProbe 的候选级诊断；不外推到所有可能的在线信号。"
        />
      </Subsection>

      <Subsection index="7.2" title="因此，当前 p=0.5 应该怎样讲">
        <p>
          这些结果只否决了所测试的 indicator-rescue 与 confidence 门控，不能证明所有在线仲裁信号都不存在，也不能推导固定日程必然过拟合。当前实现保留 pMix=0.5，是为了在缺少经验证的可靠性反馈时提供对称、中性的工程控制，同时为 AlwaysExplore、AlwaysIndicator 与 LinearSchedule 建立一个明确基线。
        </p>
        <Aside tone="warning" label="停止的主张">
          不再声称“指标代理能救回关系假阴性”，也不再把 p=0.5 描述为极小极大最优。要提升为算法贡献，必须在相同候选池、配对种子和固定模式对照下证明端到端收益。
        </Aside>
      </Subsection>
    </Section>
  );
}
