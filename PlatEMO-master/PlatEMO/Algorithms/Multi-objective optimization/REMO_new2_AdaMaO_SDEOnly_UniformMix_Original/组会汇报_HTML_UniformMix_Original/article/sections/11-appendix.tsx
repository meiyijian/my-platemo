import { Detail, Section, Subsection, Table } from "reacticle";

export function SectionAppendix() {
  return (
    <Section index="A" title="附录：数字速查与高风险问答">
      <p>
        本附录保留组会追问时最需要的数字、历史结果与证据路径。所有历史结果均标记版本，避免在口头汇报中误归因到当前 OriginalRelation。
      </p>

      <Subsection index="A.1" title="关键数字速查">
        <Table
          columns={[
            { key: "topic", label: "主题", width: "13rem" },
            { key: "numbers", label: "数字与边界" },
          ]}
          rows={[
            { topic: "支配真值稀疏", numbers: "M=10 WFG3/WFG7：约 20.1 万对中严格可比为 0；M=20 DTLZ7/WFG3/WFG7 为 0，DTLZ2 仅 44。" },
            { topic: "ε-支配补充", numbers: "WFG7，ε=0.10：M=10 为 0.8%，M=20 为 0.5%；仍不足以支撑完整标签正确率结论。" },
            { topic: "级联覆盖", numbers: "MeanRecall@K=0.444；覆盖遗憾 0.253；OracleRescue MeanCapture=0.917。仅 6 问题×2 runs 的方向性 pilot。" },
            { topic: "救援失败", numbers: "DTLZ Real−DiversityMatched=−0.0048；RealDisagreement MeanGain=−0.0015。" },
            { topic: "门控失败", numbers: "AUROC 0.620，但 GatedNegativeRate 0.371 > 0.361；FavorableProblemFraction=0。" },
            { topic: "标签参数", numbers: "k_eff：M=10→15，M=20→30；rGood=0.25；θ=5；α=1−FE/maxFE。" },
            { topic: "候选参数", numbers: "pMix=0.50；qKeep=0.80；lambda0=0.35；每代真实评价 4–6 个。" },
            { topic: "完整 GUI 参数", numbers: "gmax=3000；pMix=0.50；rGood=0.25；qKeep=0.80；lambda0=0.35；nMin=4；nMax=6。" },
          ]}
        />
      </Subsection>

      <Subsection index="A.2" title="上一版 AdaMaO 的历史性能背景">
        <Detail summary="展开历史 M=10 / FE=300 / IGD / 30-run 胜负表">
          <Table
            caption="历史结果：仅用于说明研究线背景，不代表当前简化版"
            columns={[
              { key: "baseline", label: "对比对象", width: "16rem" },
              { key: "wtl", label: "胜 / 负 / 平（16 题）", width: "14rem", align: "center" },
              { key: "reading", label: "谨慎解读" },
            ]}
            rows={[
              { baseline: "原始 REMO", wtl: "9 / 4 / 3", reading: "上一版相对基准多数问题占优。" },
              { baseline: "REMO_new2", wtl: "10 / 5 / 1", reading: "上一版多数问题占优。" },
              { baseline: "REMO_new2_WFG10", wtl: "6 / 6 / 4", reading: "上一版与直接前作总体相当。" },
              { baseline: "MCEAD", wtl: "10 / 6 / 0", reading: "上一版多数问题占优。" },
              { baseline: "R2AEA", wtl: "8 / 7 / 1", reading: "上一版基本相当。" },
              { baseline: "PIEA", wtl: "6 / 10 / 0", reading: "PIEA 胜场更多；不应隐藏。" },
            ]}
            source="源稿历史表。当前 OriginalRelation 必须重跑 FE=500、M=10/20、配对种子与 IGD/IGD+/HV。"
          />
        </Detail>
      </Subsection>

      <Subsection index="A.3" title="高风险问答">
        <Detail summary="这是不是 PIEA 与 REMO 的拼装？">
          <p>
            关系内核继承 REMO；SDE 风格标量只作为第二代理的回归目标，不直接承担 PIEA 的环境选择角色。是否构成独立贡献不由“来源不同”决定，而由严格消融能否证明标签入口或候选出口的独立效用决定。
          </p>
        </Detail>
        <Detail summary="p=0.5 随机是不是没有设计？">
          <p>
            它是缺少经验证在线仲裁信号时的中性控制，不是自适应算法，也不是理论最优。必须与 AlwaysExplore、AlwaysIndicator 和 LinearSchedule 做相同种子下的配对比较。
          </p>
        </Detail>
        <Detail summary="代码里的 uncertainty 是真的不确定性吗？">
          <p>
            不是。它等于一减去成对 softmax 最大类别概率的平均值，只能称为预测模糊度；未做概率校准，也没有区分认知与数据不确定性。
          </p>
        </Detail>
        <Detail summary="为什么不直接用上一版性能表证明算法有效？">
          <p>
            因为上一版同时包含后来删除的关系训练与门控机制，版本不同，无法归因到当前 OriginalRelation。当前版要在冻结实现、配对种子和 FE=500 下重新建立主表。
          </p>
        </Detail>
        <Detail summary="如果 HybridPBI 没有独立效用怎么办？">
          <p>
            按预注册门槛删除或收窄标签贡献，不继续为它运行高成本 S5。候选覆盖诊断仍可作为问题发现保留，但也需要扩大问题池、目标数档位和重复数后才能形成稳定研究结论。
          </p>
        </Detail>
      </Subsection>

      <Subsection index="A.4" title="本地证据路径">
        <Table
          columns={[
            { key: "kind", label: "内容", width: "14rem" },
            { key: "path", label: "本地位置" },
          ]}
          rows={[
            { kind: "当前算法入口", path: "REMO_new2_AdaMaO_SDEOnly_UniformMix_Original.m" },
            { kind: "标签构造", path: "private/HybridPBI_Classification.m" },
            { kind: "候选选择", path: "private/AdaMaOSelection.m" },
            { kind: "普通关系训练", path: "private/GetRelationPairs.m + private/DataProcess.m" },
            { kind: "标签验证计划", path: "Experiments/REMO_new2_AdaMaO_UniformMix_LabelValidation/" },
            { kind: "原始逐页讲稿", path: "组会汇报稿_UniformMix_Original.md" },
          ]}
        />
      </Subsection>
    </Section>
  );
}
