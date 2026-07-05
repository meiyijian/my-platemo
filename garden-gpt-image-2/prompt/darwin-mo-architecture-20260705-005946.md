# DARWIN-MO Architecture Diagram Prompt

Create a publication-ready academic method overview figure for a many-objective evolutionary optimization algorithm.

The diagram title must read exactly:
DARWIN-MO

The subtitle must read exactly:
Diagnostic-driven Adaptive Relation learning WIth iNdicator guidance for Many-Objective Optimization

Visual style:
- Clean CVPR / NeurIPS / IEEE paper figure style.
- White or near-white background, no gradients, no decorative textures.
- Vector-clean look, crisp black or dark slate lines, thin arrows, precise geometry.
- Landscape 16:9 canvas with generous margins.
- Use compact sans-serif typography only.
- Use no more than four muted colors total: slate, light blue, pale amber, and light green.
- All labels must be in English and must remain readable in grayscale print.
- Avoid 3D effects, drop shadows, glossy fills, cartoon icons, emoji, and dense paragraphs.

Layout:
Use a left-to-right recurrent pipeline with seven main stage blocks, plus two small controller panels above and below the central stages.
All stage blocks should be identical in height and aligned on a single horizontal baseline.
Use curved feedback arrows to show the iterative optimization loop.

Main pipeline stages, left to right:

1. "Expensive MaO Problem"
   Glyph: a small objective-space scatter plot with M axes.
   Sub-label: "decision variables X, objectives F(X)"

2. "LHS Initialization"
   Glyph: a small Latin hypercube grid.
   Sub-label: "initial Population + Archive"

3. "Hybrid PBI Classification"
   Glyph: reference vectors radiating from an ideal point, with good and bad samples.
   Sub-label: "adaptive reference vectors + dynamic Ref"
   Outputs: "Catalog", "confidence", "Ref"

4. "Adaptive Relation Learning"
   Glyph: paired samples [Xi, Xj] feeding a small neural network.
   Sub-label: "pair labels {-1, 0, +1}"
   Inside this block show three small mode chips:
   "conservative", "curriculum", "weighted"

5. "Surrogate-Guided Candidate Search"
   Glyph: a looped GA arrow producing candidate points.
   Sub-label: "OperatorGA + relation scorer"
   Inside this block show three small mode chips:
   "conservative", "explore", "indicator"

6. "Indicator-Guided Re-ranking"
   Glyph: a roulette wheel split into three slices.
   Sub-label: "SDE / I_epsilon+ / Minkowski"
   Add a tiny side note: "Lp shape estimate + SVR indicator model"

7. "Expensive Evaluation"
   Glyph: selected candidates entering a real evaluator.
   Sub-label: "new solutions update Archive"

Rightmost output:
"Updated Population"
Glyph: a compact Pareto-front scatter plot with diverse selected points.
Sub-label: "RSEA RefSelect"

Top controller panel:
Place a thin panel above stages 3 to 5 titled "Runtime Diagnostics".
Inside it show four diagnostic signals:
"p_err", "coverage", "degeneracy", "mean confidence".
Draw thin downward arrows from this panel to:
- "Adaptive Relation Learning", labelled "select relation mode"
- "Surrogate-Guided Candidate Search", labelled "select candidate mode"

Bottom controller panel:
Place a thin panel below stages 6 and 7 titled "Indicator Feedback".
Inside it show:
"score = 0 / 1 / 2"
"NDSort + NDSort_SDR"
"Update roulette probability Pw"
Draw a curved arrow from "Expensive Evaluation" down to this panel, then back to "Indicator-Guided Re-ranking".

Feedback loop:
Draw a large curved arrow from "Expensive Evaluation" / "Updated Population" back to "Hybrid PBI Classification".
Label it:
"Archive + selected population, repeat until evaluation budget is exhausted"

Important algorithmic callouts:
- In the Hybrid PBI block, show fusion text: "score_hybrid = alpha * score_v + (1-alpha) * label_dyn".
- In the Adaptive Relation Learning block, show weight text: "W(i,j) = sqrt(conf_i * conf_j)" near the weighted mode chip.
- In the Candidate Search block, show explore score text: "relation score + uncertainty + diversity".
- In the Indicator block, show the three indicator labels exactly as:
  "SDE", "I_epsilon+", "Minkowski".

Composition rules:
- Keep formulas small but legible.
- Use line arrows for data flow and dashed arrows for control signals.
- Stage blocks should have short labels only; do not place long prose inside blocks.
- Use a small legend in the bottom-right:
  solid arrow = data flow
  dashed arrow = adaptive control
  curved arrow = feedback
- The figure should look like a method architecture diagram from a high-quality many-objective optimization paper, not a business flowchart.

Negative prompt:
Do not use Chinese text in the figure.
Do not misspell DARWIN-MO.
Do not abbreviate the subtitle.
Do not create a dark cyberpunk dashboard.
Do not use neon colors, 3D rendered boxes, icons with faces, photo backgrounds, or decorative gradient blobs.
Do not make the diagram overcrowded or use tiny unreadable labels.
