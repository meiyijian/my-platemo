import { Aside, Formula, Section, Subsection, Table } from "reacticle";

export function SectionOriginalRelation() {
  return (
    <Section index="04" title="关系层：保留原始普通无权训练">
      <p>
        “OriginalRelation” 指的是关系学习部分回到普通、无权的 REMO 流程。HybridPBI 只负责生成 Catalog；之后的 <code>GetRelationPairs</code>、<code>DataProcess</code> 和三隐层 <code>patternnet</code> 不读取 HybridPBI 的连续得分，也不读取其一致性分数。这个隔离让标签构造成为可单独检验的实验因素。
      </p>

      <Subsection index="4.1" title="Catalog 被展开为四类有向关系对">
        <Table
          caption="关系样本不是任意两解的真实 Pareto 优劣，而是粗质量组之间的关系"
          columns={[
            { key: "pair", label: "配对", width: "9rem" },
            { key: "label", label: "标签", width: "6rem", align: "center" },
            { key: "interpretation", label: "解释" },
          ]}
          rows={[
            { pair: "C1 → C1", label: "0", interpretation: "两个端点都属于正组，视为同组。" },
            { pair: "C2 → C2", label: "0", interpretation: "两个端点都属于非正组，视为同组。" },
            { pair: "C1 → C2", label: "+1", interpretation: "前者来自更高粗质量组。" },
            { pair: "C2 → C1", label: "−1", interpretation: "前者来自更低粗质量组。" },
          ]}
        />
        <p>
          同组对会删除自配对，并通过随机下采样与跨组对做数量平衡。每个关系样本是两个 D 维决策向量的拼接，因此网络输入维数为 2D；输出始终是三个关系类别。
        </p>
        <Formula
          block
          tex={"2D\\;\\longrightarrow\\;[\\lceil 3D\\rceil,\\;2D,\\;D]\\;\\longrightarrow\\;\\{-1,0,+1\\}"}
          caption="当前 patternnet 的三层隐藏宽度由关系输入维数决定。"
        />
      </Subsection>

      <Subsection index="4.2" title="留出误差 p_err 测到的是什么">
        <p>
          <code>DataProcess</code> 按三个关系类别分别抽取 75% 训练、25% 测试，再对两部分独立打乱。由此得到的 <code>p_err</code> 是网络对当前伪标签的按关系对留出错误率。它在 explore 路径中衰减预测模糊度奖励，却不是候选排序增益，也不是 HybridPBI 标签相对外部真值的正确率。
        </p>
        <Aside tone="note" label="为什么还要 solution-disjoint 验证">
          按关系对随机划分时，同一个基础解可能以不同方向出现在训练集和测试集，端点信息会泄漏。后续验证必须把 E_pair、按解完全隔离的 E_solution，以及算法真实查询方式下的 E_query 分开报告。
        </Aside>
      </Subsection>

      <Subsection index="4.3" title="候选如何从关系网络得到一个分数">
        <p>
          对每个未评价候选 Xi，选择器分别构造 <code>[C1,Xi]</code>、<code>[Xi,C1]</code>、<code>[C2,Xi]</code> 与 <code>[Xi,C2]</code> 四组查询，汇总三类 softmax 输出，得到“候选偏向正组”的净证据。这个得分继承了组别监督的粗粒度：它适合做筛选和相对排序，但不能解释为 Pareto 胜率。
        </p>
      </Subsection>
    </Section>
  );
}
