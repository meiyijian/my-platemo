import { Raw } from "reacticle";

export function EvidenceLadder() {
  const levels = [
    ["01", "实现事实", "已具备", true],
    ["02", "内部诊断", "已有方向性结果", true],
    ["03", "标签外部效用", "尚未执行", false],
    ["04", "模型隔离泛化", "尚未执行", false],
    ["05", "当前版端到端", "尚未执行", false],
  ] as const;

  return (
    <Raw title="证据梯级：当前工作停在第二级">
      <div style={{ display: "grid", gap: "var(--ra-space-2)" }}>
        {levels.map(([index, label, state, filled]) => (
          <div
            key={index}
            style={{
              display: "grid",
              gridTemplateColumns: "3rem minmax(0, 1fr) minmax(8rem, 0.6fr)",
              gap: "var(--ra-space-3)",
              alignItems: "center",
              padding: "var(--ra-space-2) 0",
              borderTop: "1px solid var(--ra-color-border)",
            }}
          >
            <span style={{ fontFamily: "var(--ra-font-mono)", color: filled ? "var(--ra-color-accent)" : "var(--ra-color-muted)" }}>{index}</span>
            <span style={{ color: filled ? "var(--ra-color-heading)" : "var(--ra-color-muted)" }}>{label}</span>
            <span style={{ fontFamily: "var(--ra-font-label)", fontSize: "var(--ra-text-xs)", color: filled ? "var(--ra-color-accent)" : "var(--ra-color-risk)" }}>
              {state}
            </span>
          </div>
        ))}
      </div>
    </Raw>
  );
}
