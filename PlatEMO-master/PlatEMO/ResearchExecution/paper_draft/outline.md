# Thesis/Paper Draft Outline

## Title

Difficulty-Aware and Agent-Assisted Surrogate Optimization for Expensive Many-Objective Problems

## Abstract

Placeholder after final experiments.

## 1. Introduction

- Expensive many-objective optimization requires reducing true evaluations.
- REMO learns relation labels to screen candidate solutions.
- Existing surrogate-assisted methods may underuse objective difficulty, uncertainty, and adaptive strategy selection.
- This work contributes:
  1. a difficulty-aware uncertainty candidate selection method based on REMO;
  2. an Agent-assisted constrained strategy controller for expensive many-objective optimization;
  3. an experiment analysis Agent that turns PlatEMO results into reproducible reports.

## 2. Related Work

- Expensive multiobjective optimization.
- Relation learning in REMO.
- Kriging-assisted methods such as K-RVEA and EGO variants.
- LLM/Agent workflow automation for scientific computing.

## 3. Method 1: REMO_DiffUnc

- Baseline REMO workflow.
- Difficulty estimation.
- Uncertainty score.
- Diversity constraint.
- Candidate scoring and selection.

## 4. Method 2: Agent-Assisted REMO

- Strategy pool.
- State features.
- Rule controller.
- Constrained LLM controller.
- Safety fallback.

## 5. Experiments

- Problems: DTLZ2, DTLZ3, WFG4, WFG9.
- Objectives: 5, 10, 15 where feasible.
- Metrics: IGD, HV, runtime, true evaluations.
- Baselines: REMO, D_REMO, K-RVEA, MOEA-D-EGO, ParEGO as available.

## 6. Results and Analysis

- Main comparison.
- Ablation.
- Strategy logs.
- Failure cases.

## 7. Conclusion

- Summarize graduation workloads.
- Explain future work: stronger surrogate uncertainty, larger real-world benchmarks, richer but constrained Agent policies.
