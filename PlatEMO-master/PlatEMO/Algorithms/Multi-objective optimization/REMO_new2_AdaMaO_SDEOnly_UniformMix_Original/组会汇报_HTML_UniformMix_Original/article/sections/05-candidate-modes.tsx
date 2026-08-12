import { Aside, Formula, Section, Subsection, Table, Tradeoff } from "reacticle";
import { CandidateModeSplit } from "../raw-blocks/05-mode-split";

export function SectionCandidateModes() {
  return (
    <Section index="05" title="候选层：explore 与 indicator 两种搜索视角">
      <p>
        关系模型训练完成后，算法先用 <code>OperatorGA</code> 生成候选，并在代理辅助内循环中反复保留关系得分较高的 |Ref| 个解继续繁殖，直到累计候选数达到 gmax。去重后的候选池再进入两种最终选择路径。两条路径不改变真实评价预算，只改变“哪 4–6 个候选值得被评价”的排序依据。
      </p>

      <CandidateModeSplit />

      <Subsection index="5.1" title="explore：在关系偏好之外保留模糊与分散">
        <p>
          explore 先计算关系净证据与 softmax 预测模糊度。模糊度定义为一减去所有成对查询最大类别概率的平均值；它描述网络输出是否尖锐，不是认知不确定性，也没有经过概率校准。两项归一化后得到增强得分：
        </p>
        <Formula
          block
          tex={"s_{aug}=norm(s_{rel})+\\lambda_t norm(u),\\qquad \\lambda_t=\\lambda_0(1-ratio)\\max\\left(0,1-\\frac{p_{err}}{0.45}\\right)"}
          caption="搜索推进或关系留出误差升高时，预测模糊度奖励减弱。"
        />
        <p>
          默认 qKeep=0.80，通常保留增强得分最高约 20% 的候选；若不足 nMin，则直接补到前 nMin。最终批次用 0.75 质量与 0.25 决策空间最近距离做贪心选择。它鼓励决策向量分散，但不保证目标空间或 PF 方向多样性。
        </p>
      </Subsection>

      <Subsection index="5.2" title="indicator：关系粗筛之后再看 SDE 风格标量">
        <p>
          每代从当前种群估计 PF 形状参数 Lp，再用 <code>calFitness_SDE</code> 计算一个收敛—多样性合成标量，并用 RBF-SVR 从决策变量回归该标量。indicator 路径先按关系得分保留前 30%（至少 20 个）候选，再用 SVR 预测值重排，保留高于 70% 分位的部分并取前 nMin–nMax。
        </p>
        <Aside tone="note" label="来源与用途">
          这里使用的是 SDE 风格指标代理：标量思想与 PIEA 路线相关，但当前用途是候选重排，不是直接环境选择。若形状估计、指标计算、SVR 训练或预测失败，主程序不会把一个空模型伪装成 indicator，而是转入 explore 或退回关系得分。
        </Aside>
      </Subsection>

      <Subsection index="5.3" title="UniformMix：固定概率路由，而非自适应仲裁">
        <Table
          caption="路由与复现约束"
          columns={[
            { key: "item", label: "项目", width: "12rem" },
            { key: "behavior", label: "当前实现" },
          ]}
          rows={[
            { item: "路由概率", behavior: "指标模型可用且独立随机数 u<pMix 时走 indicator，否则走 explore。" },
            { item: "默认设置", behavior: "pMix=0.50，每代一次硬路由，不在同一批次内混合两种排名。" },
            { item: "随机性隔离", behavior: "模式路由使用由 run ID 派生的独立 RandStream，不消耗 MATLAB 全局随机流。" },
            { item: "预算保护", behavior: "候选按剩余 FE 截断；候选为空时用 GA 生成回退批次。" },
          ]}
        />
        <Tradeoff
          subject="固定 50/50 混合"
          pros={[
            "避免把尚未验证的 confidence、degeneracy 或 p_err 当作候选级收益门控。",
            "形成清楚的 AlwaysExplore / AlwaysIndicator / LinearSchedule 对照。",
            "独立随机流使路由可复现且不干扰优化轨迹的其他随机过程。",
          ]}
          cons={[
            "不能利用真实存在但尚未识别的阶段性可靠性差异。",
            "p=0.5 不是理论最优值，仍需要配对种子和固定模式消融。",
            "模式计数本身不能证明任何一个候选路径有因果贡献。",
          ]}
          verdict="当前应把 p=0.5 称为中性工程控制，而不是自适应策略或极小极大最优解。"
        />
      </Subsection>
    </Section>
  );
}
