# DARWIN-MO Candidate Selection Prompt: Indicator

Create a publication-ready academic subfigure explaining one candidate selection mode in DARWIN-MO.

Title:
DARWIN-MO Candidate Selection: Indicator Mode

Subtitle:
Relation-score coarse screening followed by PIEA-style indicator re-ranking

Visual style:
- Clean CVPR / NeurIPS / IEEE paper figure style.
- White background, thin dark slate lines, compact sans-serif typography.
- Landscape 16:9 canvas, vector-clean, precise geometry.
- Use muted slate, pale blue, pale amber, and pale green only.
- All labels must be in English.
- No Chinese text, no 3D effects, no gradients, no decorative icons, no cartoon style.

Main layout:
Draw a left-to-right pipeline with seven aligned blocks:

1. "Diagnostic Trigger"
   Glyph: low error gauge and high degeneracy indicator.
   Show the rule exactly:
   "use_indicator = true"
   "p_err <= tau_err"
   "degeneracy >= 0.45"

2. "GA Candidate Pool"
   Glyph: candidate points from the surrogate-assisted GA loop.
   Sub-label: "all_candidates"

3. "Relation Coarse Screen"
   Glyph: relation score list with top section highlighted.
   Show:
   "top 30% or at least 20"

4. "Indicator Model"
   Glyph: compact SVR model box.
   Sub-label: "fitrsvm predicts indicator fitness"

5. "PIEA Indicator Source"
   Glyph: a three-slice roulette wheel feeding the SVR box.
   Show labels exactly:
   "SDE"
   "I_epsilon+"
   "Minkowski"
   Add tiny note:
   "Lp shape estimate"

6. "Indicator Re-ranking"
   Glyph: sorted coarse candidates by predicted indicator score.
   Show:
   "keep >= quantile(scores_ind, 0.70)"

7. "Select Evaluation Batch"
   Glyph: top candidates selected.
   Sub-label: "n_min to n_max"

Rightmost output:
"Next"
Glyph: selected candidates entering expensive evaluation.

Bottom feedback strip:
Add a thin feedback strip under blocks 5 to 7:
"NewSols -> NDSort + NDSort_SDR -> score 0/1/2 -> update Pw"
Use a curved arrow from evaluation output back to the roulette wheel.

Important callouts:
- Use a dashed arrow from "Diagnostic Trigger" to "Indicator Re-ranking", labelled "activate indicator mode".
- Clearly show that relation score is used for coarse screening before indicator re-ranking.
- The roulette wheel must not look like a casino graphic; make it a minimal scientific selector.

Composition rules:
- Use solid arrows for data flow, dashed arrows for adaptive control, curved arrows for feedback.
- Keep all formulas and thresholds legible.
- The subfigure should look like part of a high-quality method paper figure for many-objective optimization.

Negative prompt:
Do not use Chinese labels.
Do not misspell I_epsilon+.
Do not make the roulette wheel decorative or cartoonish.
Do not omit the relation coarse screening stage.
Do not invent indicator values or chart data.
