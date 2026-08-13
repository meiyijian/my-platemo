import { Raw } from "reacticle";

export function StoryMap() {
  const steps = [
    ["REMO", "把目标值预测改写为关系学习"],
    ["标签入口", "HybridPBI 生成硬 Catalog"],
    ["关系内核", "原始无权三类关系训练"],
    ["候选出口", "explore / indicator 双路径"],
    ["证据门槛", "诊断、负结果与五阶段验证"],
  ];

  return (
    <Raw title="整场故事地图：只在关系学习的前后两端做受控改造">
      <div style={{ display: "grid", gap: "var(--ra-space-3)" }}>
        {steps.map(([title, body], index) => (
          <div
            key={title}
            style={{
              display: "grid",
              gridTemplateColumns: "3rem minmax(0, 0.7fr) minmax(0, 1.8fr)",
              gap: "var(--ra-space-3)",
              alignItems: "baseline",
              padding: "var(--ra-space-2) 0",
              borderTop: "1px solid var(--ra-color-border)",
            }}
          >
            <span
              style={{
                color: index === 4 ? "var(--ra-color-risk)" : "var(--ra-color-accent)",
                fontFamily: "var(--ra-font-label)",
                fontSize: "var(--ra-text-xs)",
              }}
            >
              {String(index + 1).padStart(2, "0")}
            </span>
            <strong style={{ fontWeight: "var(--ra-weight-medium)" }}>{title}</strong>
            <span style={{ color: "var(--ra-color-muted)" }}>{body}</span>
          </div>
        ))}
      </div>
    </Raw>
  );
}
