import { Raw } from "reacticle";

export function ValidationGates() {
  const gates = [
    ["S1", "机制快照审计", "机制是否真实运行"],
    ["S2", "标签因果消融", "五个混杂因素逐项拆开"],
    ["S3", "独立真实效用", "IGD+ 与未来结果是否改善"],
    ["S4", "隔离泛化", "收益能否传到未见过的解"],
    ["S5", "共同候选池 + 端到端", "差异能否转化为最终性能"],
  ];
  return (
    <Raw title="五级门控：前一级失败，就不为后一级消耗更多机时">
      <div style={{ display: "grid", gap: 0 }}>
        {gates.map(([code, title, question], index) => (
          <div
            key={code}
            style={{
              display: "grid",
              gridTemplateColumns: "4rem minmax(0, 0.85fr) minmax(0, 1.5fr) 2rem",
              gap: "var(--ra-space-3)",
              alignItems: "baseline",
              padding: "var(--ra-space-3) 0",
              borderTop: "1px solid var(--ra-color-border)",
            }}
          >
            <span style={{ color: "var(--ra-color-accent)", fontFamily: "var(--ra-font-mono)" }}>{code}</span>
            <strong style={{ fontWeight: "var(--ra-weight-medium)" }}>{title}</strong>
            <span style={{ color: "var(--ra-color-muted)" }}>{question}</span>
            <span style={{ color: index === gates.length - 1 ? "var(--ra-color-risk)" : "var(--ra-color-border-strong)" }}>
              {index === gates.length - 1 ? "■" : "↓"}
            </span>
          </div>
        ))}
      </div>
    </Raw>
  );
}
