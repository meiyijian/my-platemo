import { Raw } from "reacticle";

export function CandidateModeSplit() {
  return (
    <Raw title="同一候选池，两种观察方式">
      <svg className="algorithm-flow-desktop" viewBox="0 0 1000 430" width="100%" role="img" aria-label="explore 与 indicator 两种候选选择路径">
        <line x1="70" y1="80" x2="930" y2="80" stroke="var(--ra-color-border-strong)" strokeWidth="2" />
        <circle cx="180" cy="80" r="10" fill="var(--ra-color-accent)" />
        <circle cx="500" cy="80" r="10" fill="var(--ra-color-bg)" stroke="var(--ra-color-accent)" strokeWidth="3" />
        <circle cx="820" cy="80" r="10" fill="var(--ra-color-accent)" />
        <text x="180" y="48" textAnchor="middle" fill="var(--ra-color-heading)" fontFamily="var(--ra-font-label)" fontSize="18">GA 候选池</text>
        <text x="500" y="48" textAnchor="middle" fill="var(--ra-color-heading)" fontFamily="var(--ra-font-label)" fontSize="18">UniformMix</text>
        <text x="820" y="48" textAnchor="middle" fill="var(--ra-color-heading)" fontFamily="var(--ra-font-label)" fontSize="18">真实评价 4–6</text>

        <path d="M500 92 C500 130 310 138 310 174" fill="none" stroke="var(--ra-color-accent)" strokeWidth="3" />
        <path d="M500 92 C500 130 690 138 690 174" fill="none" stroke="var(--ra-color-accent)" strokeWidth="3" />
        <path d="M310 330 C310 374 500 374 820 92" fill="none" stroke="var(--ra-color-accent)" strokeWidth="3" />
        <path d="M690 330 C690 374 650 344 820 92" fill="none" stroke="var(--ra-color-accent)" strokeWidth="3" />

        <text x="310" y="204" textAnchor="middle" fill="var(--ra-color-accent)" fontFamily="var(--ra-font-label)" fontSize="20">EXPLORE</text>
        <line x1="190" y1="218" x2="430" y2="218" stroke="var(--ra-color-border)" strokeWidth="2" />
        <text x="310" y="252" textAnchor="middle" fill="var(--ra-color-heading)" fontFamily="var(--ra-font-label)" fontSize="17">关系得分 + 预测模糊度</text>
        <text x="310" y="280" textAnchor="middle" fill="var(--ra-color-muted)" fontFamily="var(--ra-font-label)" fontSize="15">Top 20% 左右 → 质量/距离贪心</text>
        <text x="310" y="308" textAnchor="middle" fill="var(--ra-color-muted)" fontFamily="var(--ra-font-label)" fontSize="15">决策空间分散，非目标空间保证</text>

        <text x="690" y="204" textAnchor="middle" fill="var(--ra-color-accent)" fontFamily="var(--ra-font-label)" fontSize="20">INDICATOR</text>
        <line x1="570" y1="218" x2="810" y2="218" stroke="var(--ra-color-border)" strokeWidth="2" />
        <text x="690" y="252" textAnchor="middle" fill="var(--ra-color-heading)" fontFamily="var(--ra-font-label)" fontSize="17">关系粗筛前 30%</text>
        <text x="690" y="280" textAnchor="middle" fill="var(--ra-color-muted)" fontFamily="var(--ra-font-label)" fontSize="15">SDE 风格 SVR 重排</text>
        <text x="690" y="308" textAnchor="middle" fill="var(--ra-color-muted)" fontFamily="var(--ra-font-label)" fontSize="15">指标不可用时不进入该路径</text>

        <text x="500" y="412" textAnchor="middle" fill="var(--ra-color-risk)" fontFamily="var(--ra-font-label)" fontSize="15">
          pMix=0.5 是固定路由概率；不是在线可靠性门控
        </text>
      </svg>
      <div className="algorithm-flow-mobile candidate-mode-mobile" role="img" aria-label="同一候选池的 explore 与 indicator 两种候选选择路径">
        <div className="mobile-route-source">
          <strong>GA 候选池</strong>
          <span>UniformMix 固定概率路由</span>
        </div>
        <div className="mobile-route-card">
          <span className="mobile-route-label">EXPLORE</span>
          <strong>关系得分 + 预测模糊度</strong>
          <span>Top 20% 左右 → 质量/距离贪心</span>
          <span>强调决策空间分散，不保证目标空间分散</span>
        </div>
        <div className="mobile-route-card">
          <span className="mobile-route-label">INDICATOR</span>
          <strong>关系粗筛前 30%</strong>
          <span>SDE 风格 SVR 重排</span>
          <span>指标不可用时不进入该路径</span>
        </div>
        <div className="mobile-route-target">
          <strong>真实评价 4–6 个解</strong>
          <span>pMix=0.5 是固定概率，不是在线可靠性门控</span>
        </div>
      </div>
    </Raw>
  );
}
