# DARWIN-MO Relation Mode Prompt: Curriculum

Create a publication-ready academic subfigure explaining one relation-learning mode in DARWIN-MO.

Title:
DARWIN-MO Relation Learning: Curriculum Mode

Subtitle:
High-confidence relation pairs for noisy surrogate training

Visual style:
- Clean CVPR / NeurIPS / IEEE paper figure style.
- White background, thin dark slate lines, compact sans-serif typography.
- Landscape 16:9 canvas, vector-clean, precise geometry.
- Use muted slate, pale amber, and pale blue only.
- All labels must be in English.
- No Chinese text, no 3D effects, no gradients, no decorative icons, no cartoon style.

Main layout:
Draw a left-to-right pipeline with six aligned blocks:

1. "Diagnostic Trigger"
   Glyph: a small error gauge pointing high.
   Show the rule exactly:
   "prev_p_err > tau_err"

2. "Population + Confidence"
   Glyph: decision vectors with confidence bars.
   Sub-label: "confidence from Hybrid PBI agreement"

3. "Class Split"
   Glyph: two columns labelled "C1 good" and "C2 rest".
   Sub-label: "Catalog-based split"

4. "Keep Most Confident"
   Glyph: sorted confidence bars with top portion highlighted.
   Show the rule exactly:
   "q_keep = 0.80"

5. "Pair Reconstruction"
   Glyph: selected C1 and C2 samples connected into relation pairs.
   Sub-label: "GetRelationPairs on filtered subset"

6. "Unweighted Relation Classifier"
   Glyph: paired vector [Xi, Xj] entering a compact neural network.
   Sub-label: "patternnet -> p_err"

Rightmost output:
"Cleaned relation dataset"
Glyph: a compact table with columns "XXs" and "YYs".
Sub-label: "less label noise"

Top annotation:
Add a slim title band labelled:
"Curriculum idea: train on easier high-confidence samples first"

Important callouts:
- Show the text "low-confidence samples are filtered out" beside block 4.
- Show the text "weights are empty" near the classifier block.
- Use a dashed downward arrow from "Diagnostic Trigger" to "Keep Most Confident", labelled "activate curriculum".

Composition rules:
- Use solid arrows for data flow and one dashed arrow for the adaptive trigger.
- Keep all blocks equal height and aligned.
- Make the filter operation visually clear without adding extra prose.
- The subfigure should look like part of a high-quality method paper figure for many-objective optimization.

Negative prompt:
Do not use Chinese labels.
Do not show classroom imagery.
Do not imply iterative curriculum stages beyond the actual q_keep filtering.
Do not add fabricated curves, metrics, or example datasets.
