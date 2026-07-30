# GPT Image Prompt — AdaMaO Indicator-Guided Candidate Selection

```json
{
  "type": "publication-ready academic method architecture figure",
  "goal": "Create a rigorous paper figure that explains only the indicator-guided candidate-solution mode of REMO_new2_AdaMaO. Show how an adaptive indicator surrogate and a relation surrogate jointly guide candidate screening, true evaluation, and closed-loop indicator-probability feedback. The result must look like a clean figure from an evolutionary computation or machine-learning journal, not a generic software architecture diagram.",
  "canvas": {
    "format": "single wide landscape figure, approximately 16:9",
    "background": "pure white #FFFFFF",
    "outer_padding": "generous and even",
    "composition": "two aligned horizontal lanes with a central mode gate and a right-side feedback loop",
    "rendering": "flat vector-clean appearance, sharp anti-aliased lines, precise alignment, high legibility at paper-column scale"
  },
  "title": {
    "text": "Indicator-Guided Candidate Selection in AdaMaO",
    "position": "top center",
    "style": "compact bold sans-serif, dark navy, no subtitle"
  },
  "content_scope": {
    "show": [
      "current evaluated population and archive",
      "adaptive roulette selection among SDE, additive epsilon-plus, and Minkowski indicators",
      "Lp shape estimation from the current nondominated approximation",
      "RBF-SVR indicator surrogate trained on decision vectors and selected indicator fitness",
      "indicator-mode trigger",
      "GA-generated candidate pool and upstream pairwise relation surrogate",
      "relation-score coarse screening",
      "SVR indicator-score reranking with an explicit fallback",
      "true evaluation and archive update",
      "batch-level feedback that updates indicator roulette probabilities"
    ],
    "exclude": [
      "Hybrid PBI classification details",
      "relation-pair construction and relation-network training details",
      "conservative mode",
      "explore mode",
      "unrelated algorithm modules",
      "benchmark curves or claimed performance gains"
    ]
  },
  "layout": {
    "left_input_column": {
      "main_box": {
        "label": "Current Evaluated Population  P_t",
        "sub_labels": ["Decision vectors  X_t", "Objective vectors  F_t"],
        "glyph": "a small, precise scatter of solution dots next to a compact matrix glyph"
      },
      "secondary_box": {
        "label": "Archive  A_t",
        "glyph": "a minimal stacked-record glyph"
      }
    },
    "upper_lane": {
      "lane_label": "A  Adaptive Indicator Surrogate",
      "stages_left_to_right": [
        {
          "name": "Nondominated Approximation",
          "sub_label": "first front of P_t",
          "glyph": "a thin two-objective Pareto-front curve with a few dots; schematic only, no numeric axes"
        },
        {
          "name": "Shape Estimation",
          "sub_label": "estimate Lp",
          "glyph": "three simple contour arcs representing different Lp shapes"
        },
        {
          "name": "Roulette Indicator Selector",
          "sub_label": "sample using P_w",
          "internal_items": ["SDE", "I_epsilon+", "Minkowski(Lp)"],
          "glyph": "a restrained three-sector circular selector, not a colorful casino wheel",
          "annotation": "initial P_w = (1/3, 1/3, 1/3)"
        },
        {
          "name": "Indicator Fitness",
          "sub_label": "fitness values on P_t",
          "glyph": "a vertical list of solution dots with short scalar bars; no invented numbers"
        },
        {
          "name": "RBF-SVR Indicator Surrogate",
          "sub_label": "X_t  ->  predicted indicator score",
          "glyph": "a compact kernel surface or smooth regression curve with training dots; no axes or numeric values"
        }
      ],
      "special_connections": [
        "Draw a small arrow from Shape Estimation to the SDE and Minkowski(Lp) items, but not to I_epsilon+.",
        "If the sampled indicator fitness is invalid, show a tiny dashed fallback label: fallback to SDE."
      ]
    },
    "center_gate": {
      "shape": "precise diamond",
      "title": "Indicator Mode Gate",
      "conditions": [
        "use_indicator = 1",
        "p_err <= tau_err",
        "degeneracy >= 0.45"
      ],
      "formula_note": "degeneracy = 1 - rank90 / M",
      "true_edge": "solid amber arrow labeled TRUE leading into indicator-guided reranking",
      "false_edge": "very light gray short dotted edge labeled other modes, not shown"
    },
    "lower_lane": {
      "lane_label": "B  Indicator-Guided Candidate Selection",
      "external_input_box": {
        "label": "Pairwise Relation Surrogate  R_theta",
        "sub_label": "upstream trained; provides relation score and p_err",
        "style": "small gray-blue external-input box"
      },
      "stages_left_to_right": [
        {
          "name": "Surrogate-Assisted GA",
          "sub_label": "Population + Ref -> offspring",
          "glyph": "a minimal mutation-and-recombination branching glyph",
          "internal_loop": "thin loop labeled relation-guided inner iterations"
        },
        {
          "name": "Candidate Pool  C",
          "sub_label": "accumulate and deduplicate",
          "glyph": "multiple pale candidate dots merging into one clean set"
        },
        {
          "name": "Relation Coarse Screen",
          "sub_label": "top 30%, at least 20",
          "glyph": "a funnel retaining the highest relation-score candidates"
        },
        {
          "name": "Indicator Reranking",
          "sub_label": "predict with RBF-SVR",
          "glyph": "an ordered stack of candidate cards with upward score arrow",
          "fallback": "dashed arrow from relation score labeled SVR unavailable or invalid -> reuse relation score"
        },
        {
          "name": "Final Batch",
          "sub_labels": [">= 70th percentile", "select n_min ... n_max"],
          "glyph": "a small highlighted subset of candidate dots"
        },
        {
          "name": "True Evaluation",
          "sub_label": "Delta P_t",
          "glyph": "a clean objective-function evaluation symbol, not a computer-server icon"
        }
      ]
    },
    "right_feedback_column": {
      "stages_top_to_bottom": [
        {
          "name": "Archive Update",
          "sub_label": "A_t+1 = A_t union Delta P_t"
        },
        {
          "name": "Batch Feedback",
          "sub_labels": ["NDSort + NDSort_SDR", "score s in {0, 1, 2}"]
        },
        {
          "name": "Sliding-Window Update",
          "sub_labels": ["20 generations", "Choose_record and Win_record", "renormalize P_w"]
        }
      ],
      "feedback_arrow": "a single clean curved amber arrow returning from Sliding-Window Update to Roulette Indicator Selector, labeled adaptive indicator probabilities",
      "next_iteration_arrow": "a thin gray arrow from Archive Update through RefSelect to the next population P_t+1"
    }
  },
  "connectors": {
    "main_flow": "solid dark navy arrows, left to right",
    "cross_lane_flow": "muted amber arrows only for the mode gate, SVR guidance, and feedback",
    "fallbacks": "thin dashed gray arrows",
    "rules": [
      "arrows must never cross labels or pass through blocks",
      "use orthogonal or gently curved connectors",
      "make the main causal route obvious within two seconds",
      "keep feedback visually secondary to forward candidate selection"
    ]
  },
  "visual_system": {
    "palette": {
      "primary": "deep navy #1F3A5F for outlines, headings, and main flow",
      "indicator_lane": "very light desaturated blue #E8EFF6",
      "candidate_lane": "very light desaturated teal #E4F0ED",
      "accent": "muted amber #B9853B only for the gate and feedback loop",
      "neutral": "charcoal #30343B and cool gray #6B7280"
    },
    "block_style": "uniform rounded rectangles, approximately 6 px corner radius, 1.2 px borders, no shadows",
    "lane_style": "subtle pale background bands or slim braces, not large decorative panels",
    "icons": "minimal scientific line glyphs with consistent stroke width"
  },
  "typography": {
    "language": "English only",
    "font": "Helvetica, Inter, or Arial",
    "hierarchy": "bold module names, smaller regular sub-labels, compact italic notes",
    "text_accuracy": "render every label exactly as specified; do not paraphrase, duplicate, or invent labels",
    "formula_style": "plain clean mathematical notation; no handwritten equations"
  },
  "scientific_integrity": {
    "must_show": [
      "the relation surrogate performs the first coarse screen before the indicator surrogate reranks candidates",
      "the indicator surrogate is trained only on the current evaluated population",
      "the RBF-SVR fallback returns to relation scores when the model is missing or invalid",
      "true evaluation occurs only after final batch selection",
      "feedback updates roulette probabilities using the newly evaluated batch"
    ],
    "small_footer_note": "Batch feedback is updated whenever indicator fitness exists; it is not conditioned on confirmed successful SVR use.",
    "do_not_invent": [
      "performance values",
      "convergence curves",
      "IGD or HV improvements",
      "extra equations",
      "unseen thresholds",
      "dataset or benchmark names"
    ]
  },
  "negative_prompt": [
    "no dark background",
    "no gradient",
    "no drop shadow",
    "no glassmorphism",
    "no 3D blocks",
    "no glossy or neon colors",
    "no cartoon characters",
    "no robot, brain, cloud, database, or server icons",
    "no decorative grid texture",
    "no fake charts",
    "no photorealistic imagery",
    "no mixed Chinese and English",
    "no tiny unreadable paragraphs",
    "no overlapping arrows",
    "no unequal or misaligned stage blocks",
    "no extra modules outside the indicator-guided candidate mode"
  ],
  "final_quality_target": "A restrained, geometrically precise, grayscale-readable, publication-ready academic pipeline figure suitable for the Methods section of an evolutionary many-objective optimization paper."
}
```
