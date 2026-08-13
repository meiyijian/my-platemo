import { Aside, Section, Subsection, Table } from "reacticle";
import { StoryMap } from "../raw-blocks/01-story-map";

export function SectionResearchOrigin() {
  return (
    <Section index="01" title="研究起点：REMO 把目标值预测改写为关系学习">
      <p>
        昂贵多目标优化最稀缺的不是候选解，而是真实评价次数。传统逐目标回归代理路线通常为各个目标建立回归模型；目标数增加时，需要维护的模型数、数据需求和联合误差都会上升。REMO 的关键转向是：不直接预测每个目标值，而是学习两个决策向量之间的粗质量关系，再用这种关系指导内层进化和真实评价分配。
      </p>
      <p>
        这条范式降低了输出维数，却没有让目标数从问题中消失。关系标签仍然来自目标空间中的 PBI 分组，标签如何构造、代表解能否覆盖当前分布，都会随目标数与前沿几何变化。UniformMix-OriginalRelation 的研究起点因此不是“否定 REMO”，而是沿着它的信息流追问两个更具体的问题。
      </p>

      <StoryMap />

      <Subsection index="1.1" title="REMO 的五步主循环">
        <Table
          caption="基线流程：从已评价种群到下一批真实评价候选"
          columns={[
            { key: "step", label: "步骤", width: "7rem" },
            { key: "module", label: "模块", width: "16rem" },
            { key: "role", label: "作用" },
          ]}
          rows={[
            { step: "1", module: "RefSelect", role: "从已评价解中选代表解。" },
            { step: "2", module: "GetOutput_PBI", role: "把种群划分为粗质量组，形成 Catalog。" },
            { step: "3", module: "GetRelationPairs", role: "构造同组与跨组关系对，生成 0 / +1 / −1 标签。" },
            { step: "4", module: "patternnet", role: "学习决策空间中的组别关系。" },
            { step: "5", module: "RSurrogateAssistedSelection", role: "在内层 GA 候选池上关系投票，选出下一批真实评价解。" },
          ]}
          source="基线：REMO.m、GetOutput_PBI.m、GetRelationPairs.m 与 RSurrogateAssistedSelection.m。"
        />
      </Subsection>

      <Subsection index="1.2" title="本文把问题拆成两个接口">
        <p>
          第一个接口在网络之前：当目标数达到 10 或 20 时，怎样用更丰富的方向信息生成粗质量组，而不是长期依赖固定数量的代表解？第二个接口在网络之后：当关系排序与一个收敛—多样性指标代理给出不同候选视角时，怎样分配每代仅 4–6 次真实评价？
        </p>
        <Aside tone="principle" label="研究边界">
          当前工作只声称“实现了两处受控改造，并为它们建立了可检验假设”。支配型外部真值稀疏、候选覆盖缺口或静态代码正确，都不能单独证明新标签更准确、双路径性能更好。
        </Aside>
      </Subsection>
    </Section>
  );
}
