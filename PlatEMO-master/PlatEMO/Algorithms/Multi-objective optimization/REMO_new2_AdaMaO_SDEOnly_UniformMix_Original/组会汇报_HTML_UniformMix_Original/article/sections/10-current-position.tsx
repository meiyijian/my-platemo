import { Decision, Section, Subsection, Table } from "reacticle";

export function SectionCurrentPosition() {
  return (
    <Section index="10" title="结论：这项工作现在处于什么位置">
      <p>
        UniformMix-OriginalRelation 已经形成一条闭合的算法信息流：HybridPBI 从当前种群构造硬 Catalog；原始关系网络学习三类组别关系；SDE 风格 SVR 提供第二种候选排序；UniformMix 在每代选择 explore 或 indicator；小批候选被真实评价并回到 Archive。这个版本最大的价值是边界清楚，适合做严格消融。
      </p>
      <p>
        它同时还不是一个由正式性能结果支撑的最终算法。现有诊断建立了可测问题，并且主动否决了一个看起来合理的 indicator-rescue 故事；但 HybridPBI 的独立外部效用、solution-disjoint 迁移以及当前简化版的端到端性能仍为空白。下一步的研究问题不是“还能加什么”，而是“哪些部分在证据面前应当留下”。
      </p>

      <Subsection index="10.1" title="可以讲成候选贡献的三层结构">
        <Table
          caption="从问题到机制，再到证据"
          columns={[
            { key: "layer", label: "层级", width: "12rem" },
            { key: "story", label: "当前故事" },
            { key: "status", label: "证据状态", width: "18rem" },
          ]}
          rows={[
            { layer: "问题诊断", story: "many-objective 下外部关系真值稀疏；当前 indicator 级联存在候选覆盖缺口。", status: "已有方向性 pilot，需扩大验证。" },
            { layer: "算法机制", story: "在关系学习前端重构标签，在后端引入两种候选视角，同时冻结普通无权关系训练。", status: "已实现并具备消融边界。" },
            { layer: "验证方法", story: "用五阶段链条分离机制存在、标签效用、模型迁移与端到端性能。", status: "计划已成文，尚未全部执行。" },
          ]}
        />
      </Subsection>

      <Decision
        question="本轮组会后，最合理的投入顺序是什么？"
        options={[
          "立即启动完整 30-run 主对比",
          "先执行 S1–S4，按门槛决定是否进入 S5",
          "继续增加自适应门控与新代理",
        ]}
        criteria={[
          "先排除 α 空转与 K-means 分支少触发两个致命机制风险",
          "标签效用必须用独立于 PBI 与 SDE 的真实 PF 指标验证",
          "候选层必须在固定模式和配对种子下证明价值",
        ]}
        recommended="先执行 S1–S4，按门槛决定是否进入 S5"
        rationale="这是当前信息量下最小、最有辨识力的投入：任何早期失败都能触发删除或收窄主张，避免把机时花在无法归因的端到端结果上。"
      />

      <Subsection index="10.2" title="下一次组会应带回三个答案">
        <ol>
          <li>HybridPBI 的连续项是否真实改变排序，K-means 方向分支实际触发了多少代？</li>
          <li>在打乱、均匀方向与 AnchorNative 对照下，哪一个标签因素具有独立 IGD+ 效用？</li>
          <li>当训练解与测试解完全隔离时，标签收益还能否传递到关系模型和真实查询？</li>
        </ol>
      </Subsection>
    </Section>
  );
}
