import { Article, Conclusion, Hero, Lead, Raw, Summary } from "reacticle";
import { SectionResearchOrigin } from "./sections/01-research-origin";
import { SectionCurrentVersion } from "./sections/02-current-version";
import { SectionHybridPBI } from "./sections/03-hybrid-pbi";
import { SectionOriginalRelation } from "./sections/04-original-relation";
import { SectionCandidateModes } from "./sections/05-candidate-modes";
import { SectionDiagnostics } from "./sections/06-diagnostics";
import { SectionNegativeResults } from "./sections/07-negative-results";
import { SectionEvidenceLedger } from "./sections/08-evidence-ledger";
import { SectionValidationRoadmap } from "./sections/09-validation-roadmap";
import { SectionCurrentPosition } from "./sections/10-current-position";
import { SectionAppendix } from "./sections/11-appendix";

export function ArticleDoc() {
  return (
    <Article toc width="wide">
      <Hero
        eyebrow="UniformMix · OriginalRelation"
        title="UniformMix-OriginalRelation"
        subtitle="在 REMO 关系学习框架中，重构高维伪标签与候选选择"
        meta={[
          { label: "日期", value: "2026-08-12" },
          { label: "类型", value: "组会算法汇报" },
          { label: "入口", value: "REMO_new2_AdaMaO_SDEOnly_UniformMix_Original.m" },
          { label: "范围", value: "机制 · 代码 · 诊断 · 验证计划" },
        ]}
      />
      <Lead>
        故事从一个受限预算的问题开始：当一次真实评价很贵、总预算只有几百次时，与其为每个目标预测精确数值，能否只学习“两个解之间是什么关系”？REMO 证明了这条路线可行。UniformMix-OriginalRelation 沿着这条路线继续前进：保留原始关系学习内核，只重构进入网络之前的伪标签，以及离开网络之后的候选选择。
      </Lead>

      <Summary
        title="四句话看懂这项工作"
        points={[
          "继承：关系对构造、三类关系标签、3/4–1/4 数据划分与普通无权 patternnet 训练保持 REMO 逻辑。",
          "标签重构：HybridPBI 融合数据依赖方向场的连续 PBI 得分与代表解二值标签，再硬化为 Top-rGood Catalog。",
          "候选双路径：explore 强调关系得分、预测模糊度和决策空间分散；indicator 先关系粗筛，再用 SDE 风格 SVR 重排。",
          "当前定位：算法和消融边界已经成形，诊断结果否决了 indicator-rescue 故事；标签独立效用与当前版端到端性能仍需五阶段验证。",
        ]}
      />

      <SectionResearchOrigin />
      <SectionCurrentVersion />
      <SectionHybridPBI />
      <SectionOriginalRelation />
      <SectionCandidateModes />
      <SectionDiagnostics />
      <SectionNegativeResults />
      <SectionEvidenceLedger />
      <SectionValidationRoadmap />
      <SectionCurrentPosition />
      <SectionAppendix />

      <Conclusion
        title="收束"
        takeaways={[
          "先确认 HybridPBI 的连续项和数据依赖方向场是否真实参与排序。",
          "再用独立 IGD+ 效用与 solution-disjoint 泛化判断标签是否值得保留。",
          "只有证据通过门槛，才讨论当前版本的正式端到端性能与候选层扩展。",
        ]}
      >
        这不是一份“机制越多越好”的算法故事。它真正想建立的是一条可被证伪的因果链：关系学习为什么需要新的标签入口，两种候选视角怎样在固定预算下工作，已有负结果砍掉了什么，以及下一组实验将决定哪些部分留下。
      </Conclusion>

      <Raw title="">
        <footer
          style={{
            marginTop: "var(--ra-space-7, 3rem)",
            paddingTop: "var(--ra-space-4, 1rem)",
            borderTop: "1px solid var(--ra-color-border, currentColor)",
            color: "var(--ra-color-muted, inherit)",
            fontSize: "var(--ra-text-xs, 0.78rem)",
            textAlign: "center",
            letterSpacing: "0.02em",
            opacity: 0.85,
          }}
        >
          Made with{" "}
          <a
            href="https://github.com/ConardLi/garden-skills"
            target="_blank"
            rel="noopener noreferrer"
            style={{ color: "inherit", textDecoration: "underline", textUnderlineOffset: "0.2em" }}
          >
            beautiful-article
          </a>{" "}
          · tufte theme
        </footer>
      </Raw>
    </Article>
  );
}
