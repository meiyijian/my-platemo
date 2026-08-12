import { Raw } from "reacticle";

export function StopChain() {
  const rows = [
    ["H1", "覆盖缺口存在", "PASS", "var(--ra-color-accent)"],
    ["H2", "指标正分歧可识别假阴性", "FAIL", "var(--ra-color-risk)"],
    ["H4", "置信度可做候选级门控", "FAIL", "var(--ra-color-risk)"],
    ["决策", "INDICATOR-RESCUE STORY", "STOP", "var(--ra-color-risk)"],
  ];
  return (
    <Raw title="预注册判决链：诊断成立，不代表救援成立">
      <div style={{ display: "grid", gap: 0 }}>
        {rows.map(([code, claim, verdict, color], index) => (
          <div
            key={code}
            style={{
              display: "grid",
              gridTemplateColumns: "5rem minmax(0, 1fr) 6rem",
              gap: "var(--ra-space-3)",
              alignItems: "center",
              padding: "var(--ra-space-3) 0",
              borderTop: "1px solid var(--ra-color-border)",
              borderBottom: index === rows.length - 1 ? "1px solid var(--ra-color-border-strong)" : undefined,
            }}
          >
            <span style={{ fontFamily: "var(--ra-font-mono)", color }}>{code}</span>
            <span>{claim}</span>
            <strong style={{ color, fontFamily: "var(--ra-font-label)", fontSize: "var(--ra-text-xs)", letterSpacing: "0.1em" }}>
              {verdict}
            </strong>
          </div>
        ))}
      </div>
    </Raw>
  );
}
