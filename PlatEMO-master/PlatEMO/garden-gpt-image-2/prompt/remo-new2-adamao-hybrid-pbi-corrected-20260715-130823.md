# Corrected GPT Image 2 prompt — REMO_new2_AdaMaO Hybrid PBI

This prompt replaces the incorrect “global reference-vector view + local reference-solution view” narrative. It depicts the current many-objective execution path as **two representations derived from the same current population**.

```json
{
  "type": "publication-ready academic mechanism and module-architecture figure",
  "goal": "Create a precise figure of the actual REMO_new2_AdaMaO Hybrid PBI classification module. The key scientific message is same-population dual-representation PBI fusion, not global-local fusion.",
  "canvas": {
    "aspect_ratio": "16:9 landscape",
    "background": "pure white #FFFFFF",
    "outer_padding": "generous, approximately 6 percent of canvas width",
    "render_quality": "high-resolution, vector-clean, sharp readable mathematical text, suitable for an IEEE two-column paper"
  },
  "title": {
    "text": "Hybrid PBI Classification: Same-Population Dual-Representation Fusion",
    "position": "top center",
    "style": "compact bold sans-serif, dark slate"
  },
  "layout": {
    "reading_order": "left to right",
    "structure": "one shared input on the left, two parallel representation branches in the middle, one fusion-and-grouping stage, and outputs on the right",
    "alignment": "strict grid alignment, equal branch heights, no crossing arrows",
    "source_bracket": {
      "text": "Two representations derived from the same current population",
      "position": "a thin bracket spanning both branches directly after the shared input",
      "importance": "visually prominent enough to prevent any global-versus-local interpretation"
    }
  },
  "shared_input": {
    "label": "Current population P_t",
    "contents": [
      "evaluated solutions",
      "objective matrix F(P_t)",
      "evolution ratio rho = FE / maxFE"
    ],
    "depiction": "a restrained objective-space point cloud entering a clean split node; do not draw a fabricated Pareto front or numerical axes"
  },
  "upper_branch": {
    "heading": "Representation A — Population-Derived Direction Field",
    "source_flow": [
      "F(P_t)",
      "current nondominated subset",
      "per-objective normalization",
      "K-means centroids",
      "unit direction set V_t"
    ],
    "main_path_condition": "many-objective main path: M > 3 and N >= 50, with sufficient nondominated samples",
    "visual_glyph": "small objective-space sketch with current points, several centroid-derived rays, one associated solution, its projection onto a ray, longitudinal distance d1, and perpendicular distance d2",
    "association": "associate each solution with the most cosine-similar direction",
    "formula_block": [
      "PBI_v(i) = d1(i) + theta d2(i)",
      "s_v(i) = 1 / (1 + PBI_v(i))"
    ],
    "output_label": "continuous direction-field score s_v",
    "fallback_note": "small dashed side box only: if M <= 3, N < 50, samples are insufficient, or adaptive construction fails, use UniformPoint directions. Do not reinterpret this fallback as a separate global signal."
  },
  "lower_branch": {
    "heading": "Representation B — Representative-Solution Anchors",
    "source_flow": [
      "P_t",
      "RefSelect(P_t, k)",
      "k evaluated representative solutions R_t",
      "anchor-region assignment by cosine similarity",
      "GetOutput_PBI"
    ],
    "visual_glyph": "the same current point cloud represented by a few highlighted actual solution anchors, with each point assigned to one anchor region; anchors must be points selected from P_t, not external priors",
    "formula_block": [
      "g_i = (d1_i + delta d2_i) / ||R_j - z_min||",
      "y_dyn(i) = 1 if g_i <= 1, otherwise 0"
    ],
    "adaptive_threshold": "delta is selected by binary search over [-20, 20] to seek a positive-label ratio between 0.3 and 0.7; delta may be negative, so never describe it as an always-positive deviation penalty",
    "output_label": "binary anchor-threshold label y_dyn"
  },
  "fusion_stage": {
    "heading": "Evolution-Progress Fusion",
    "formula_block": [
      "alpha = 1 - rho",
      "s_h(i) = alpha s_v(i) + (1 - alpha) y_dyn(i)"
    ],
    "interpretation": [
      "early evolution emphasizes the continuous direction-field score",
      "late evolution emphasizes the representative-anchor binary label"
    ],
    "forbidden_interpretation": "Do not write early global versus late local, global prior versus local refinement, or global-local cooperation."
  },
  "agreement_stage": {
    "heading": "Cross-Representation Agreement",
    "formula": "a_i = 1 - |s_v(i) - y_dyn(i)|",
    "annotation": "code variable: confidence; meaning: agreement between two PBI representations, not probability of correctness"
  },
  "ranking_and_grouping": {
    "flow": [
      "sort all solutions by s_h in descending order",
      "positive group = top ceil(N/4)",
      "non-positive group = remaining 3N/4"
    ],
    "important_detail": "show the bottom ceil(N/4) as bad_idx only with a thin optional marker, while making clear that Catalog itself does not separate the middle half from the bottom quarter",
    "catalog_formula": "Catalog(i) = true only for the top quarter; false otherwise"
  },
  "outputs": {
    "items": [
      "Catalog: positive / non-positive grouping",
      "agreement scores a",
      "representative solutions Ref = R_t",
      "good_idx and bad_idx"
    ],
    "downstream_note": "Catalog and agreement scores support relation-pair construction; Ref supports later candidate selection"
  },
  "visual_style": {
    "palette": {
      "shared_population": "dark slate #334155",
      "direction_field_branch": "muted deep blue #315A7D",
      "anchor_branch": "muted teal #3F7C78",
      "fusion_highlight": "low-saturation amber #C89B4A",
      "fills": "very light tints only"
    },
    "shapes": "flat rounded rectangles with 1.2 px outlines, small objective-space line glyphs, simple triangle arrowheads",
    "typography": "English labels only, Inter or Helvetica, short phrases, consistent hierarchy",
    "printability": "must remain understandable in grayscale; use branch labels and line patterns in addition to color"
  },
  "semantic_guardrails": {
    "must_show": [
      "both branches originate from the same current population",
      "direction-field continuous scoring and representative-anchor binary labeling are different representations and different quantizations",
      "the hybrid operation is the weighted fusion of a continuous score and a binary label",
      "agreement is not calibrated confidence",
      "Catalog is top-quarter versus the rest"
    ],
    "must_not_show_or_say": [
      "Global Reference-Vector View",
      "Local Dynamic Reference-Solution View",
      "global plus local",
      "global prior corrects local bias",
      "independent global and local information sources",
      "true Pareto good/bad labels",
      "confidence equals correctness probability",
      "all Catalog=false solutions are the explicit bottom-quarter bad_idx",
      "a fixed positive delta",
      "fabricated objective values, performance curves, accuracy numbers, or Pareto fronts"
    ]
  },
  "caption": "The current population is transformed into two PBI representations: a nondominated-distribution direction field producing a continuous score and representative evaluated anchors producing a binary threshold label. Evolution-progress fusion yields a coarse top-quarter grouping, while their agreement supplies a heuristic training weight.",
  "negative_prompt": "Avoid glossy AI infographic style, business dashboard aesthetics, generic global-local icons, globe or map symbols, zoom-lens metaphors for locality, 3D blocks, gradients, shadows, neon colors, decorative gears, robots, fake charts, fake Pareto fronts, invented data, illegible tiny text, mixed languages, crossing arrows, inconsistent block sizes, or mathematically altered formulas."
}
```

