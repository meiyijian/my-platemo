# DARWIN-MO Runtime Diagnostics Prompt

Create a publication-ready academic subfigure explaining the runtime diagnostic controller in DARWIN-MO.

Title:
DARWIN-MO Runtime Diagnostics

Subtitle:
Population-state and surrogate-error signals drive adaptive mode selection

Visual style:
- Clean CVPR / NeurIPS / IEEE paper figure style.
- White background, thin dark slate lines, compact sans-serif typography.
- Landscape 16:9 canvas, vector-clean, precise geometry.
- Use muted slate, pale blue, pale amber, and pale green only.
- All labels must be in English.
- No Chinese text, no 3D effects, no gradients, no decorative icons, no cartoon style.

Main layout:
Use a three-column diagnostic controller layout:

Left column: "Inputs"
Show four compact input cards:
1. "Population.objs"
   Glyph: small objective-space scatter plot.
2. "confidence"
   Glyph: vertical confidence bars.
3. "p_err"
   Glyph: classifier error gauge.
4. "prev_p_err"
   Glyph: one-step memory arrow.

Middle column: "Diagnostic Computation"
Draw three stacked computation panels:

Panel A: "Coverage"
Glyph: reference vectors with assigned population directions.
Show:
"Uniform reference vectors"
"coverage = occupied refs / total refs"

Panel B: "Degeneracy"
Glyph: normalized objective matrix feeding SVD bars.
Show:
"SVD energy"
"degeneracy = 1 - rank90 / M"

Panel C: "Mean Confidence"
Glyph: average bar from confidence values.
Show:
"mean_conf = mean(confidence)"

Right column: "Adaptive Decisions"
Draw two decision panels:

Decision panel 1:
Title: "Relation Mode"
Show a compact rule table:
"if prev_p_err > tau_err -> curriculum"
"else if prev_p_err <= tau_err and mean_conf >= 0.55 and coverage < 0.60 -> weighted"
"else -> conservative"

Decision panel 2:
Title: "Candidate Mode"
Show a compact rule table:
"if use_indicator and p_err <= tau_err and degeneracy >= 0.45 -> indicator"
"else if p_err <= tau_err and coverage < 0.60 -> explore"
"else -> conservative"

Bottom strip:
Draw a recurrent feedback strip:
"new Archive + selected Population -> next generation diagnostics"
Use a curved arrow from the right column back to the left column.

Important callouts:
- Use dashed arrows from diagnostic outputs to decision panels.
- Use solid arrows inside the computation panels.
- Make "coverage", "degeneracy", "mean_conf", "p_err", and "prev_p_err" visually prominent.
- Include a small legend:
  solid arrow = computed flow
  dashed arrow = control signal
  curved arrow = generation feedback

Composition rules:
- Use short labels only; no dense paragraphs.
- Keep rule tables legible and aligned.
- Do not show exact runtime data plots; this is a mechanism diagram.
- The subfigure should look like part of a high-quality method paper figure for many-objective optimization.

Negative prompt:
Do not use Chinese labels.
Do not fabricate numerical traces or experiment results.
Do not turn this into a software dashboard.
Do not use neon colors or dark background.
Do not omit the decision rules.
