# DARWIN-MO Candidate Selection Prompt: Conservative

Create a publication-ready academic subfigure explaining one candidate selection mode in DARWIN-MO.

Title:
DARWIN-MO Candidate Selection: Conservative Mode

Subtitle:
Relation-score ranking with minimal expensive evaluations

Visual style:
- Clean CVPR / NeurIPS / IEEE paper figure style.
- White background, thin dark slate lines, compact sans-serif typography.
- Landscape 16:9 canvas, vector-clean, precise geometry.
- Use muted slate and pale blue only.
- All labels must be in English.
- No Chinese text, no 3D effects, no gradients, no decorative icons, no cartoon style.

Main layout:
Draw a left-to-right pipeline with five aligned blocks:

1. "GA Candidate Pool"
   Glyph: scattered candidate points generated from Input and Ref.
   Sub-label: "OperatorGA inner loop"

2. "Relation Scorer"
   Glyph: candidate Xi compared against good and rest classes.
   Show four comparison mini-tiles:
   "[C1, Xi]"
   "[Xi, C1]"
   "[C2, Xi]"
   "[Xi, C2]"

3. "Score Aggregation"
   Glyph: two evidence bars labelled "good evidence" and "bad evidence".
   Show formula:
   "score = C_SCORE(1) - C_SCORE(2)"

4. "Rank Candidates"
   Glyph: vertical sorted list with highest score at top.
   Sub-label: "sort descending"

5. "Select Top n_min"
   Glyph: top small set highlighted.
   Sub-label: "minimal evaluation batch"

Rightmost output:
"Next"
Glyph: selected candidates entering expensive evaluation.

Top annotation:
Add a small mode badge above the pipeline:
"Trigger: default / low model trust"

Important callouts:
- Near block 2, show "model_select".
- Near block 5, show "n_eval = min(n_min, available)".
- Use no uncertainty, no diversity, and no indicator branch in this diagram.

Composition rules:
- Use solid arrows for data flow.
- Keep all blocks equal height and aligned.
- Make the conservative logic visually simple and stable.
- The subfigure should look like part of a high-quality method paper figure for many-objective optimization.

Negative prompt:
Do not use Chinese labels.
Do not include SDE, I_epsilon+, Minkowski, or SVR in this mode.
Do not show uncertainty weighting or diversity selection.
Do not add fabricated example scores.
