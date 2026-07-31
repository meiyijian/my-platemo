# AdaMaO UniformMix Fixed Relation-Training Modes Design

## Goal

Use `REMO_new2_AdaMaO_SDEOnly_UniformMix` as the unchanged behavioral baseline
and add three experiment entries that differ only in how the relation network is
trained:

1. always agreement-weighted;
2. always curriculum-filtered;
3. always original unweighted.

No optimization experiments are part of this change.

## Controlled Factor

The three fixed modes map to the existing training paths as follows:

| Entry suffix | Fixed mode | Relation-pair preparation | Network training |
| --- | --- | --- | --- |
| `Weighted` | `weighted` | `GetRelationPairs_confidence` | `DataProcess_confidence` and error weights |
| `Curriculum` | `curriculum` | retain the top 80% confidence samples within each group, then call `GetRelationPairs` | `DataProcess` without error weights |
| `Original` | `conservative` | `GetRelationPairs` | `DataProcess` without error weights |

All three versions retain the hard `0/+1/-1` relation labels. The curriculum
version keeps the existing fixed 80% confidence filter; it does not introduce a
new generation-dependent schedule.

## Architecture

The frozen `REMO_new2_AdaMaO_SDEOnly_UniformMix` entry and
`REMO_new2_AdaMaO_SDEOnly_ModeBase` runtime will remain byte-for-byte
unchanged. A new
`REMO_new2_AdaMaO_SDEOnly_UniformMix_RelationModeBase` will copy that runtime
once, fix the candidate policy to `uniform_mix`, and replace only the inline
adaptive relation-mode decision with a protected `relationPairMode` hook.

Three thin subclasses of the new fixed-policy runtime will override only
`relationPairMode`:

- `REMO_new2_AdaMaO_SDEOnly_UniformMix_Weighted`
- `REMO_new2_AdaMaO_SDEOnly_UniformMix_Curriculum`
- `REMO_new2_AdaMaO_SDEOnly_UniformMix_Original`

Each override returns one fixed mode string. The main loop is duplicated only
once in the shared experimental runtime, rather than once per variant. This
keeps the existing baseline protected by its regression hash while giving all
three new entries the same implementation.

## Runtime Flow

For every generation, the shared runtime will:

1. compute `Catalog`, confidence, references, and diagnostics exactly as before;
2. ask `relationPairMode` for the training mode;
3. execute the existing weighted, curriculum, or original pair-preparation path;
4. train the existing relation network;
5. continue through the unchanged SDE indicator, uniform candidate routing,
   surrogate-assisted selection, evaluation, and archive update.

Empty relation-pair handling and training-error behavior remain unchanged.

## Invariants

The change must not alter:

- initialization, population size, or algorithm parameters;
- `HybridPBI_Classification`, `Catalog`, confidence, or reference generation;
- relation-network architecture or label encoding;
- the `UniformMix` candidate probability and random-stream draw position;
- indicator-model training, candidate generation, selection, evaluation, or
  archive update;
- the default adaptive relation routing used by existing algorithms;
- the contents and Git blob hashes of
  `REMO_new2_AdaMaO_SDEOnly_UniformMix.m` and
  `REMO_new2_AdaMaO_SDEOnly_ModeBase.m`.

## Verification

A focused MATLAB unit test will first require the three new entry classes and
their fixed modes. It will also verify:

- all three entries inherit from the new shared fixed-policy runtime;
- the shared experimental runtime fixes candidate policy to `uniform_mix` and
  delegates only relation-mode choice to the mode hook;
- only the three intended fixed mode strings are returned by the new entries;
- the existing frozen-baseline hash test still passes.

After implementation, verification will consist of focused non-optimization
tests, the existing frozen-baseline hash test, MATLAB `checkcode` on changed
and added files, and a Git diff review. These are code-validity checks only; no
optimization run or performance claim is included.
