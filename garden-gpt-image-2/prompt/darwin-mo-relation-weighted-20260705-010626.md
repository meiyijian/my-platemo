# DARWIN-MO Relation Mode Prompt: Weighted

Create a publication-ready academic subfigure explaining one relation-learning mode in DARWIN-MO.

Title:
DARWIN-MO Relation Learning: Weighted Mode

Subtitle:
Confidence-weighted pairwise relations under reliable but under-covered search

Visual style:
- Clean CVPR / NeurIPS / IEEE paper figure style.
- White background, thin dark slate lines, compact sans-serif typography.
- Landscape 16:9 canvas, vector-clean, precise geometry.
- Use muted slate, pale green, and pale blue only.
- All labels must be in English.
- No Chinese text, no 3D effects, no gradients, no decorative icons, no cartoon style.

Main layout:
Draw a left-to-right pipeline with six aligned blocks:

1. "Diagnostic Trigger"
   Glyph: three small status indicators.
   Show the rule exactly:
   "prev_p_err <= tau_err"
   "mean_conf >= 0.55"
   "coverage < 0.60"

2. "Hybrid PBI Outputs"
   Glyph: a small classifier panel with three outputs.
   Show output labels:
   "Catalog", "confidence", "Ref"

3. "Confidence Pairing"
   Glyph: two samples Xi and Xj connected by a weighted edge.
   Show formula:
   "W(i,j) = sqrt(conf_i * conf_j)"

4. "Weighted Relation Dataset"
   Glyph: a table with columns "XXs", "YYs", "WWs".
   Sub-label: "pair samples, labels, weights"

5. "Weighted Data Process"
   Glyph: train/test split with synchronized weights.
   Sub-label: "DataProcess_confidence"

6. "Weighted Relation Classifier"
   Glyph: compact neural network with thicker input lines for higher weights.
   Show:
   "EW normalized, floor = w_min"

Rightmost output:
"p_err"
Glyph: a small validation gauge.
Sub-label: "weighted test error"

Top annotation:
Add a slim title band labelled:
"Higher-confidence relation pairs influence training more strongly"

Important callouts:
- Near block 3, highlight "geometric mean confidence".
- Near block 6, show "sample-weighted patternnet training".
- Use a dashed downward arrow from "Diagnostic Trigger" to "Weighted Relation Dataset", labelled "activate weighting".

Composition rules:
- Use solid arrows for data flow and one dashed arrow for adaptive control.
- Keep formulas compact and legible.
- Do not make the network architecture detailed; the focus is the weighting mechanism.
- The subfigure should look like part of a high-quality method paper figure for many-objective optimization.

Negative prompt:
Do not use Chinese labels.
Do not draw a generic deep learning architecture.
Do not omit the weight formula.
Do not add fabricated performance numbers.
