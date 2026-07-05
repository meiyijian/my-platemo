# DARWIN-MO Candidate Selection Prompt: Explore

Create a publication-ready academic subfigure explaining one candidate selection mode in DARWIN-MO.

Title:
DARWIN-MO Candidate Selection: Explore Mode

Subtitle:
Relation score augmented by uncertainty and decision-space diversity

Visual style:
- Clean CVPR / NeurIPS / IEEE paper figure style.
- White background, thin dark slate lines, compact sans-serif typography.
- Landscape 16:9 canvas, vector-clean, precise geometry.
- Use muted slate, pale amber, and pale green only.
- All labels must be in English.
- No Chinese text, no 3D effects, no gradients, no decorative icons, no cartoon style.

Main layout:
Draw a left-to-right pipeline with seven aligned blocks:

1. "Diagnostic Trigger"
   Glyph: good error gauge and low coverage indicator.
   Show the rule exactly:
   "p_err <= tau_err"
   "coverage < 0.60"

2. "GA Candidate Pool"
   Glyph: many candidate points.
   Sub-label: "unique all_candidates"

3. "Relation Score + Uncertainty"
   Glyph: two aligned columns labelled "scores" and "uncertainty".
   Sub-label: "model_select"

4. "Adaptive Exploration Weight"
   Glyph: a decaying curve over evolution ratio.
   Show formula:
   "lambda_t = lambda0 * (1 - ratio) * max(0, 1 - p_err / 0.45)"

5. "Augmented Score"
   Glyph: two signals merging.
   Show formula:
   "score_aug = norm(score) + lambda_t * norm(uncertainty)"

6. "Quantile Filter"
   Glyph: sorted score bars with threshold line.
   Show:
   "keep score_aug >= quantile(score_aug, q_keep)"

7. "Diversity Selection"
   Glyph: selected points spread apart in decision space.
   Show acquisition formula:
   "acq = 0.75 * score_norm + 0.25 * distance_norm"

Rightmost output:
"Next: n_min to n_max candidates"
Glyph: diverse selected candidates entering expensive evaluation.

Top annotation:
Add a slim title band labelled:
"Explore reliable but under-covered regions"

Important callouts:
- Use a dashed arrow from "Diagnostic Trigger" to "Adaptive Exploration Weight", labelled "activate explore".
- In the diversity block, show "greedy max-min distance".
- Make uncertainty visually distinct from score but keep colors muted.

Composition rules:
- Use solid arrows for data flow and one dashed arrow for adaptive control.
- Keep formulas compact and legible.
- Do not include the indicator SVR branch in this mode.
- The subfigure should look like part of a high-quality method paper figure for many-objective optimization.

Negative prompt:
Do not use Chinese labels.
Do not add fake numeric examples beyond the actual formula constants.
Do not show a random exploration cloud without the score and diversity mechanisms.
Do not draw a generic reinforcement learning diagram.
