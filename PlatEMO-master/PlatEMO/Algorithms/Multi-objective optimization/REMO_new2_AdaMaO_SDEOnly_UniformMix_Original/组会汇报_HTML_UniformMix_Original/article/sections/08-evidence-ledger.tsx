import { Aside, Section, Subsection, Table } from "reacticle";
import { EvidenceLadder } from "../raw-blocks/08-evidence-ladder";

export function SectionEvidenceLedger() {
  return (
    <Section index="08" title="当前证据账本：实现、诊断、历史结果与空白">
      <p>
        一份完整算法汇报既要讲机制，也要说明机制处在什么证据阶段。UniformMix-OriginalRelation 的代码边界和复现路径已经清楚，内部诊断也提供了值得继续验证的问题；但标签独立效用、模型迁移和当前简化版端到端性能尚未完成。把这四类证据混为一谈，会让算法故事比实验事实走得更远。
      </p>

      <EvidenceLadder />

      <Subsection index="8.1" title="已完成：独立实现与可复现迁移">
        <Table
          caption="当前可以作为实现事实陈述的内容"
          columns={[
            { key: "item", label: "项目", width: "17rem" },
            { key: "evidence", label: "已有记录" },
            { key: "boundary", label: "边界" },
          ]}
          rows={[
            { item: "独立算法入口", evidence: "7 个参数；普通 GetRelationPairs + DataProcess 训练；private 依赖闭合。", boundary: "说明版本可运行、可消融。" },
            { item: "迁移验证", evidence: "迁移时记录 31/31 测试通过、Code Analyzer 0 消息。", boundary: "静态/回归验证不是性能证据。" },
            { item: "轨迹一致性", evidence: "记录中验证了 FE、Archive 与全局 RNG 轨迹对齐。", boundary: "证明迁移没有意外漂移，不证明新机制有效。" },
            { item: "路由复现", evidence: "模式随机数来自独立 RandStream，并由 run ID 派生。", boundary: "支持配对实验，不支持模式优劣结论。" },
          ]}
          source="OriginalRelation 独立迁移记录与当前源码；正式投稿前应在冻结版本上重新归档完整日志。"
        />
      </Subsection>

      <Subsection index="8.2" title="已有诊断：能提出问题，也能否决错误方向">
        <p>
          ConfidenceProbe 说明支配型外部真值在 many-objective 设置下不足，并揭示某些内部置信分数的尺度、类别与几何依赖。Cascade pilot 建立了当前 indicator 级联的候选覆盖缺口，同时否决了所测试的指标救援与候选级门控。它们的共同价值是缩小问题和停止错误故事，而不是替代当前算法的正式性能实验。
        </p>
        <Aside tone="note" label="WFG3 结果放在哪里">
          WFG3 上的 PBI 一致性反向、网络分数互补与 degeneracy 诊断属于历史 ConfidenceProbe 结果；当前 OriginalRelation 主程序没有 confidence/degeneracy 门控。它们适合作为未来假设与附录，不应画成已实现回退架构。
        </Aside>
      </Subsection>

      <Subsection index="8.3" title="仍然缺少：对当前简化版的性能归因">
        <p>
        源稿中的 M=10、FE=300、IGD、30-run 胜负表来自上一版 AdaMaO 配置。该表仅说明上一版本能够完成基本搜索，不能证明当前 OriginalRelation “没有性能损失”，更不能归因到 HybridPBI 或 UniformMix。正式证据需要在相同冻结版本上使用 FE=500、配对种子，并同时报告 IGD、IGD+ 与 HV。
        </p>
      </Subsection>
    </Section>
  );
}
