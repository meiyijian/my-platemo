import { Raw } from "reacticle";

export function DiagnosticBoundaries() {
  const items = [
    {
      tag: "诊断 A",
      finding: "支配型外部真值在 M≥10 时高度稀疏",
      supports: "需要重新设计标签外部效用的测量方法",
      excludes: "不证明 HybridPBI 更准确，也不证明 REMO 的 PBI 标签消失",
    },
    {
      tag: "诊断 B",
      finding: "当前 indicator 级联的关系粗筛存在覆盖缺口",
      supports: "候选池中有被粗筛遗漏的 oracle-useful 解",
      excludes: "不证明 indicator-rescue 有效，也不属于原始 REMO 的 top-30% 机制",
    },
  ];

  return (
    <Raw title="两个诊断位于不同作用层，不能互相替代">
      <div
        style={{
          display: "grid",
          gridTemplateColumns: "repeat(auto-fit, minmax(min(100%, 19rem), 1fr))",
          gap: "var(--ra-space-6)",
        }}
      >
        {items.map((item) => (
          <div key={item.tag} style={{ borderTop: "2px solid var(--ra-color-accent)", paddingTop: "var(--ra-space-3)" }}>
            <div style={{ fontFamily: "var(--ra-font-label)", fontSize: "var(--ra-text-xs)", color: "var(--ra-color-accent)", letterSpacing: "0.1em" }}>
              {item.tag}
            </div>
            <p style={{ margin: "var(--ra-space-2) 0 var(--ra-space-4)", fontSize: "var(--ra-text-lg)", lineHeight: "var(--ra-leading-snug)" }}>
              {item.finding}
            </p>
            <div style={{ borderTop: "1px solid var(--ra-color-border)", paddingTop: "var(--ra-space-2)", color: "var(--ra-color-heading)" }}>
              可支持：{item.supports}
            </div>
            <div style={{ marginTop: "var(--ra-space-2)", color: "var(--ra-color-risk)" }}>
              不支持：{item.excludes}
            </div>
          </div>
        ))}
      </div>
    </Raw>
  );
}
