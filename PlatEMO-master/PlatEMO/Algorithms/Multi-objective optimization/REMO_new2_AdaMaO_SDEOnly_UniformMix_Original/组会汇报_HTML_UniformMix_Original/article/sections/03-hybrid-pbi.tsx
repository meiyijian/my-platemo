import { Aside, Formula, Image, Section, Subsection, Table } from "reacticle";
import hybridPbiFigure from "../assets/hybrid-pbi-cycle1.png";

export function SectionHybridPBI() {
  return (
    <Section index="03" title="标签层：HybridPBI 如何生成 Catalog">
      <p>
        关系网络并不直接看到目标值，它看到的是由 Catalog 派生的关系对。因此，Catalog 是整条信息链的入口。HybridPBI 的设计目标是让这个入口同时包含两种来自当前种群的表征：一条连续的方向场得分，以及一条由代表解产生的二值锚点标签。
      </p>
      <p>
        两种表征都依赖当前 Population，它们不是相互独立的全局真值。它们的价值在于提供不同分辨率：连续项给出排序裕量，二值项给出与 REMO 兼容的粗分组边界。最终结果仍会被硬化为正组 / 非正组，因此当前改动改变的是伪标签的组成和样本分布，而不是把关系网络改造成连续监督。
      </p>

      <Subsection index="3.1" title="第一条支路：当前分布方向场">
        <p>
          代表解数量随目标数增长，默认取 <code>k_eff=min(N,max(6,⌈1.5M⌉))</code>：M=10 时为 15，M=20 时为 30。对于 M&gt;3 且种群规模不少于 50 的情形，算法尝试从当代第一前沿提取非支配解，将其归一化后做 K-means，并把簇中心映射回目标空间作为数据依赖方向。低维、小样本、非支配解不足、目标范围退化或聚类失败时，回退到均匀 ILD 向量。
        </p>
        <Formula
          block
          tex={"PBI_i=d_{1,i}+\\theta d_{2,i},\\qquad score_{v,i}=\\frac{1}{1+PBI_i},\\qquad \\theta=5"}
          caption="每个解先关联到最相近方向，再把投影距离与垂直距离转为连续得分。"
        />
      </Subsection>

      <Subsection index="3.2" title="第二条支路：代表解锚点标签">
        <p>
          同一代中，<code>RefSelect</code> 从当前种群选出 k_eff 个实际评价代表解；<code>GetOutput_PBI</code> 据此产生 <code>{"label_dyn∈{0,1}"}</code>。搜索早期使用较大的连续方向场权重，后期逐渐转向代表解二值边界。
        </p>
        <Formula
          block
          tex={"\\alpha=1-\\frac{FE}{maxFE},\\qquad score_{hybrid}=\\alpha score_v+(1-\\alpha)label_{dyn}"}
          caption="阶段融合改变排序来源，但两个分量的统计语义并不相同。"
        />
      </Subsection>

      <div className="hybridpbi-figure-desktop">
        <Image
          src={hybridPbiFigure}
          alt="HybridPBI 从数据依赖方向场和代表解锚点生成融合得分，再硬化为 Catalog 的机制图"
          caption="HybridPBI 的真实数据流：连续方向场得分与二值锚点标签融合，按排名截取正组。"
          credit="本项目科研架构图：混合PBI_cycle1.png"
          width="92%"
        />
      </div>

      <figure
        className="hybridpbi-figure-mobile"
        role="img"
        aria-label="HybridPBI 从当前种群产生两条标签支路，经阶段融合后硬化为 Catalog"
      >
        <figcaption>HybridPBI 移动端机制速览</figcaption>
        <div className="hybrid-mobile-source">
          <strong>当前 Population</strong>
          <span>同一批已评价目标值</span>
        </div>
        <div className="hybrid-mobile-branches">
          <div className="hybrid-mobile-branch">
            <span>连续支路</span>
            <strong>数据依赖方向场</strong>
            <code>PBI → score_v</code>
          </div>
          <div className="hybrid-mobile-branch">
            <span>二值支路</span>
            <strong>代表解锚点</strong>
            <code>label_dyn ∈ {`{0,1}`}</code>
          </div>
        </div>
        <div className="hybrid-mobile-merge">
          <span>阶段融合</span>
          <strong>α·score_v + (1−α)·label_dyn</strong>
          <small>早期偏连续方向场，后期偏二值锚点</small>
        </div>
        <div className="hybrid-mobile-output">
          <strong>按排名截取 Top-rGood</strong>
          <span>输出硬 Catalog：正组 / 非正组</span>
        </div>
        <p>改变的是伪标签组成与样本分布，不是连续关系监督。</p>
      </figure>

      <Subsection index="3.3" title="硬化：只把排名前 rGood 的解送入正组">
        <Table
          caption="HybridPBI 的输出及其证据含义"
          columns={[
            { key: "output", label: "输出", width: "11rem" },
            { key: "meaning", label: "代码含义" },
            { key: "not", label: "不能解释为" },
          ]}
          rows={[
            { output: "score_v", meaning: "数据依赖方向上的连续 PBI 变换。", not: "真实 Pareto 质量或独立效用。" },
            { output: "label_dyn", meaning: "代表解锚点产生的二值 PBI 标签。", not: "校准概率。" },
            { output: "confidence", meaning: "1−|score_v−label_dyn| 的同源一致性分数。", not: "标签正确概率或当前门控信号。" },
            { output: "Catalog", meaning: "融合排名前 ceil(N·rGood) 为 true，其余为 false。", not: "连续关系监督。" },
          ]}
        />
        <Aside tone="warning" label="最关键的边界">
          当前实现能证明 HybridPBI 被正确接入，但不能证明其标签更准确。尤其要先确认连续项的方差是否足以改变排序，以及高维 K-means 方向分支究竟触发了多少代。
        </Aside>
      </Subsection>
    </Section>
  );
}
