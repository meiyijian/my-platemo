import { Aside, Section, Subsection, Table } from "reacticle";
import { RuntimeLoop } from "../raw-blocks/02-runtime-loop";

export function SectionCurrentVersion() {
  return (
    <Section index="02" title="当前版本：一次有意的减法">
      <p>
        当前入口是 <code>REMO_new2_AdaMaO_SDEOnly_UniformMix_Original.m</code>。它没有继续叠加关系置信度加权、curriculum 路由或多重门控，而是把普通无权关系训练恢复为独立主线，只保留 HybridPBI 标签构造与双候选路径。这样做的目的不是追求最少代码，而是把后续消融的因果边界固定下来。
      </p>
      <p>
        初始化阶段按决策维数确定种群规模：<code>D≤10</code> 时使用 <code>11D−1</code> 个 Latin 超立方样本，否则使用 100 个。所有已评价解进入 Archive；每代重新选择种群、构造标签、训练关系模型与指标代理，再从内层 GA 产生的候选池中选择 4–6 个解进行真实评价。
      </p>

      <RuntimeLoop />

      <Subsection index="2.1" title="相对 REMO 的代码级差异">
        <Table
          caption="七个发生改变或新增的运行环节"
          columns={[
            { key: "part", label: "环节", width: "9rem" },
            { key: "remo", label: "REMO", width: "29%" },
            { key: "current", label: "UniformMix-OriginalRelation" },
          ]}
          rows={[
            {
              part: "伪标签",
              remo: "固定 k=6 代表解产生 PBI 二值组别。",
              current: "k_eff=min(N,max(6,⌈1.5M⌉))；连续方向场与代表解标签融合后取 Top-rGood。",
            },
            {
              part: "方向来源",
              remo: "代表解锚点。",
              current: "高维且样本足够时使用当代非支配集 K-means 中心，否则回退均匀 ILD。",
            },
            {
              part: "关系训练",
              remo: "四类关系对、三类标签、普通无权 patternnet。",
              current: "保持同一算法逻辑，只增加空输入与 NaN/Inf 防御。",
            },
            {
              part: "第二代理",
              remo: "无。",
              current: "SDE 风格指标作为回归目标，用 RBF-SVR 对未评价候选排序。",
            },
            {
              part: "候选路径",
              remo: "单一关系投票。",
              current: "explore 与 indicator 两种路径；可用时按 pMix 路由。",
            },
            {
              part: "批次",
              remo: "score>3.9，不足时取前 4。",
              current: "分位筛选、质量—距离贪心与固定 4–6 个真实评价名额。",
            },
            {
              part: "工程保护",
              remo: "单一路径。",
              current: "独立路由随机流、指标不可用回退 explore、空候选 GA 回退、剩余预算截断。",
            },
          ]}
          source="对照当前入口与 REMO 主程序、选择器；“保持”指算法逻辑等价，不指逐字节相同。"
        />
      </Subsection>

      <Subsection index="2.2" title="七个公开参数">
        <Table
          caption="默认配置"
          columns={[
            { key: "name", label: "参数", width: "8rem" },
            { key: "default", label: "默认值", width: "7rem", align: "right" },
            { key: "meaning", label: "含义" },
          ]}
          rows={[
            { name: "gmax", default: "3000", meaning: "每代代理辅助 GA 的累计候选样本上限。" },
            { name: "pMix", default: "0.50", meaning: "指标路径可用时选择 indicator 的概率。" },
            { name: "rGood", default: "0.25", meaning: "Catalog 中正组比例。" },
            { name: "qKeep", default: "0.80", meaning: "explore 路径的增强得分保留分位点。" },
            { name: "lambda0", default: "0.35", meaning: "预测模糊度奖励的初始强度。" },
            { name: "nMin", default: "4", meaning: "每代最少真实评价候选数。" },
            { name: "nMax", default: "6", meaning: "每代最多真实评价候选数。" },
          ]}
        />
        <Aside tone="note" label="减法的意义">
          被删除的 confidence 加权、curriculum 与旧门控并不是被证明无效，而是它们会让标签变化和关系训练变化无法归因。当前版本先冻结关系训练，再单独回答标签与候选路径是否有价值。
        </Aside>
      </Subsection>
    </Section>
  );
}
