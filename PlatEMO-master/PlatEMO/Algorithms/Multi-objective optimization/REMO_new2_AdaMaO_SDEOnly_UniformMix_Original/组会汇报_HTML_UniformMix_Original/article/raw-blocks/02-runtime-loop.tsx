import { Raw } from "reacticle";

export function RuntimeLoop() {
  const nodes = [
    ["已评价档案", "Archive"],
    ["环境选择", "RefSelect"],
    ["伪标签", "HybridPBI"],
    ["关系模型", "patternnet"],
    ["指标代理", "SDE + SVR"],
    ["候选路由", "UniformMix"],
    ["真实评价", "4–6 个解"],
  ];

  return (
    <Raw title="当前版本的一代：两类代理共享同一批已评价数据">
      <svg className="algorithm-flow-desktop" viewBox="0 0 1000 260" width="100%" role="img" aria-label="UniformMix OriginalRelation 每代运行流程">
        <path
          d="M80 104 H920"
          fill="none"
          stroke="var(--ra-color-border-strong)"
          strokeWidth="2"
        />
        {nodes.map(([label, code], index) => {
          const x = 80 + index * 140;
          return (
            <g key={label}>
              <circle
                cx={x}
                cy="104"
                r={index === 5 ? 12 : 9}
                fill={index === 5 ? "var(--ra-color-accent)" : "var(--ra-color-bg)"}
                stroke="var(--ra-color-accent)"
                strokeWidth="3"
              />
              <text
                x={x}
                y={index % 2 === 0 ? 62 : 156}
                textAnchor="middle"
                fill="var(--ra-color-heading)"
                fontFamily="var(--ra-font-label)"
                fontSize="18"
              >
                {label}
              </text>
              <text
                x={x}
                y={index % 2 === 0 ? 82 : 178}
                textAnchor="middle"
                fill="var(--ra-color-muted)"
                fontFamily="var(--ra-font-mono)"
                fontSize="14"
              >
                {code}
              </text>
            </g>
          );
        })}
        <path
          d="M920 104 C966 104 970 220 850 220 H150 C54 220 42 140 80 104"
          fill="none"
          stroke="var(--ra-color-muted)"
          strokeWidth="2"
          strokeDasharray="10 9"
        />
        <text
          x="500"
          y="246"
          textAnchor="middle"
          fill="var(--ra-color-muted)"
          fontFamily="var(--ra-font-label)"
          fontSize="15"
        >
          新解并入 Archive；剩余预算不足时截断，候选为空时由 GA 回退
        </text>
      </svg>
      <div className="algorithm-flow-mobile" role="img" aria-label="UniformMix OriginalRelation 每代运行流程，纵向七步">
        {nodes.map(([label, code], index) => (
          <div className={`mobile-flow-step${index === 5 ? " is-accent" : ""}`} key={label}>
            <span className="mobile-flow-index">{String(index + 1).padStart(2, "0")}</span>
            <strong>{label}</strong>
            <code>{code}</code>
          </div>
        ))}
        <p className="mobile-flow-note">
          新解并入 Archive 后进入下一代；剩余预算不足时截断，候选为空时由 GA 回退。
        </p>
      </div>
    </Raw>
  );
}
