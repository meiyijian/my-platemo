# DARWIN-MO Relation Mode Prompt: Conservative

Create a publication-ready academic subfigure explaining one relation-learning mode in DARWIN-MO.

Title:
DARWIN-MO Relation Learning: Conservative Mode

Subtitle:
Stable pairwise relation construction without confidence weighting

Visual style:
- Clean CVPR / NeurIPS / IEEE paper figure style.
- White background, thin dark slate lines, compact sans-serif typography.
- Landscape 16:9 canvas, vector-clean, precise geometry.
- Use muted slate and pale blue only, plus one pale gray background tint.
- All labels must be in English.
- No Chinese text, no 3D effects, no gradients, no decorative icons, no cartoon style.

Main layout:
Draw a left-to-right pipeline with five aligned blocks:

1. "Population + Catalog"
   Glyph: a small set of decision vectors X with binary tags.
   Sub-label: "C1 = good, C2 = rest"

2. "Split Classes"
   Glyph: two clean columns labelled "C1" and "C2".
   Sub-label: "from Hybrid PBI labels"

3. "Pair Construction"
   Glyph: four small pair tiles.
   Show exactly these relation pair types:
   "C1-C1 -> 0"
   "C2-C2 -> 0"
   "C1-C2 -> +1"
   "C2-C1 -> -1"

4. "Balance + Remove Self Pairs"
   Glyph: a small filter funnel and equal-width bars.
   Sub-label: "balanced same-class and cross-class pairs"

5. "Relation Classifier"
   Glyph: paired vector [Xi, Xj] entering a compact neural network.
   Sub-label: "patternnet predicts {-1, 0, +1}"

Rightmost output:
"p_err"
Glyph: a small test-set gauge.
Sub-label: "classification error for next diagnostic cycle"

Top annotation:
Add a small mode badge above the pipeline:
"Trigger: default / robust fallback"

Important callouts:
- Near the classifier block, show "No sample weights".
- Near the pair construction block, show "XXs = [Xi, Xj], YYs in {-1, 0, +1}".
- Add a tiny note at bottom: "Used when curriculum and weighted conditions are not activated."

Composition rules:
- Use solid arrows for data flow.
- Keep all blocks equal height and aligned.
- Do not crowd the figure with MATLAB function names except optional tiny captions: "GetRelationPairs" and "TrainRelationModel".
- The subfigure should look like part of a high-quality method paper figure for many-objective optimization.

Negative prompt:
Do not use Chinese labels.
Do not use colorful business icons.
Do not draw a full system diagram; focus only on conservative relation learning.
Do not add fabricated metrics or example numbers.
