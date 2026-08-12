export function Cover() {
  return (
    <section
      className="ra-cover"
      aria-label="UniformMix-OriginalRelation 组会汇报封面"
      data-ra-cover=""
      style={{
        position: "relative",
        width: "100%",
        maxWidth: "min(100%, 48rem, calc((100vh - 8rem) * 3 / 4))",
        margin: "0 auto var(--ra-space-7, 3rem) auto",
        aspectRatio: "3 / 4",
        overflow: "hidden",
        background: "transparent",
        color: "var(--ra-color-fg, inherit)",
        borderRadius: "var(--ra-radius-md, 0)",
        border: "1px solid var(--ra-color-border, currentColor)",
        isolation: "isolate",
      }}
    >
      <AlgorithmCover />
    </section>
  );
}

function AlgorithmCover() {
  return (
    <>
      <svg
        viewBox="0 0 1200 1600"
        preserveAspectRatio="xMidYMid meet"
        aria-hidden="true"
        style={{ position: "absolute", inset: 0, width: "100%", height: "100%" }}
      >
        <line x1="104" y1="118" x2="1096" y2="118" stroke="var(--ra-color-border)" strokeWidth="2" />
        <line x1="104" y1="1482" x2="1096" y2="1482" stroke="var(--ra-color-border)" strokeWidth="2" />

        <path
          d="M214 1050 C356 1050 390 906 534 906"
          fill="none"
          stroke="var(--ra-color-accent)"
          strokeWidth="5"
        />
        <path
          d="M534 906 C672 906 688 804 810 804"
          fill="none"
          stroke="var(--ra-color-accent)"
          strokeWidth="5"
        />
        <path
          d="M534 906 C672 906 688 1008 810 1008"
          fill="none"
          stroke="var(--ra-color-accent)"
          strokeWidth="5"
        />
        <path
          d="M842 804 C966 804 970 906 1050 906 M842 1008 C966 1008 970 906 1050 906"
          fill="none"
          stroke="var(--ra-color-accent)"
          strokeWidth="5"
        />
        <path
          d="M1050 906 C1094 1066 1008 1212 812 1240 C576 1276 362 1198 214 1050"
          fill="none"
          stroke="var(--ra-color-muted)"
          strokeWidth="3"
          strokeDasharray="16 15"
        />

        <circle cx="214" cy="1050" r="23" fill="var(--ra-color-bg)" stroke="var(--ra-color-accent)" strokeWidth="5" />
        <circle cx="534" cy="906" r="23" fill="var(--ra-color-bg)" stroke="var(--ra-color-accent)" strokeWidth="5" />
        <circle cx="810" cy="804" r="17" fill="var(--ra-color-accent)" />
        <circle cx="810" cy="1008" r="17" fill="var(--ra-color-bg)" stroke="var(--ra-color-accent)" strokeWidth="4" />
        <circle cx="1050" cy="906" r="23" fill="var(--ra-color-bg)" stroke="var(--ra-color-accent)" strokeWidth="5" />

        <line x1="174" y1="1050" x2="254" y2="1050" stroke="var(--ra-color-border)" strokeWidth="2" />
        <line x1="494" y1="906" x2="574" y2="906" stroke="var(--ra-color-border)" strokeWidth="2" />
        <line x1="1010" y1="906" x2="1090" y2="906" stroke="var(--ra-color-border)" strokeWidth="2" />
      </svg>

      <div
        style={{
          position: "absolute",
          inset: "10% 9% auto 9%",
          zIndex: 1,
          display: "grid",
          gap: "var(--ra-space-3)",
          maxWidth: "76%",
        }}
      >
        <span
          style={{
            fontFamily: "var(--ra-font-label)",
            fontSize: "var(--ra-text-xs)",
            letterSpacing: "0.18em",
            color: "var(--ra-color-muted)",
          }}
        >
          UNIFORMMIX · ORIGINAL RELATION
        </span>
        <h1
          style={{
            margin: 0,
            fontFamily: "var(--ra-font-heading)",
            fontSize: "var(--ra-text-4xl)",
            lineHeight: 1.08,
            whiteSpace: "pre-line",
          }}
        >
          {"关系之上，\n双路搜索"}
        </h1>
        <p
          style={{
            margin: 0,
            color: "var(--ra-color-muted)",
            fontSize: "var(--ra-text-sm)",
            lineHeight: 1.5,
          }}
        >
          高维昂贵多目标优化中的标签重构与候选对冲
        </p>
      </div>

      <div
        style={{
          position: "absolute",
          left: "9%",
          right: "9%",
          bottom: "7%",
          zIndex: 1,
          display: "flex",
          justifyContent: "space-between",
          gap: "var(--ra-space-4)",
          alignItems: "end",
          color: "var(--ra-color-muted)",
          fontFamily: "var(--ra-font-label)",
          fontSize: "var(--ra-text-xs)",
          lineHeight: 1.5,
        }}
      >
        <span>组会汇报 · 2026-08-12</span>
        <span style={{ textAlign: "right" }}>
          标签生成 → 关系学习<br />
          双路径候选 → 真实评价
        </span>
      </div>
    </>
  );
}
