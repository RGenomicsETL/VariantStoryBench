# VariantStoryBench relation and metric contract

Current executable authority: validators/metrics in `R/` and tests in `inst/tinytest/`.
This document clarifies public use without changing runtime schemas or behavior.
New temporal relations are proposed in [temporal-benchmark.md](temporal-benchmark.md).

## Public inputs and labels

Public source adapters may supply existing result/metric contracts directly.
They do not have to use the developer-fixture generator.
Outcome labels are public but are not prediction inputs.
Keep provider/release/date, task, candidate universe and method configuration explicit.

## Current result relations

| Relation | Identity and meaning |
|---|---|
| `cases` | `case_id`, `target_type`; truth status is known_causal, unresolved or confirmed_negative |
| `truth` | case/target/causal ID; known-causal units have at least one expected causal row |
| `runs` | run ID; engine/version/source/profile/cutoff/resources and run status |
| `evaluations` | run/case/target; completed, failed, unsupported or skipped |
| `candidates` | run/case/target/candidate; unique contiguous ranks for completed evaluations |
| `allele_observations` | case/source-record/ALT ordinal; source and canonical geometry and admission state |
| `genotype_observations` | adds person identity; GT/GQ/DP, copy count, ploidy, phase and call state |
| `frequency_observations` | case/allele/provider row; lossless key, match/filter state, AC/AN/AF and FAF fields |
| `judgments` / `judgment_sources` | claim/source identity with exact cited source spans and stance |

Preserve existing schemas exactly when calling current validators.
`bench_rank_metrics()` includes failed/skipped/unsupported known-causal units as misses.
Keep unresolved and confirmed-negative burden separate. Break score ties by candidate ID.
`bench_grounding_metrics()` measures source-audit coverage, not evidence correctness.
`bench_validate_frequency_observations()` is not a PM2 evaluator.
It requires lowercase 16-character hexadecimal VariantKey and its existing missingness/range rules.

## Case and transport interfaces

`persons`: case_id, person_id, vcf_sample_id, is_proband, sex, affected.
`relationships`: case_id, person_id, relative_id, relationship.
Use the existing affected/unaffected/unknown vocabulary and explicit sample mappings.
`documents` retains case/document identity and source_text.
HPO observations wrap the existing ducksemantics observation fields with person/case identity.
Present source spans are zero-based half-open and nonempty.
Missing denominators have NA rates, not a perfect score.

Call states distinguish called alternate, called reference, partial no-call, no-call and other alternate.
REF/ALT orientation is not pathogenicity. Preserve original multiallelic mapping and reference identity.
Genotype transport compares values without silently imposing a quality threshold.
CNV/SV coordinate meaning follows its event type; do not use one conversion for all VCF records.

## Existing developer fixtures

`bench_generate_micro_cohort()` still returns `engine_input` and `evaluator_truth`.
These are ordinary test-data/result-reference bundles, not the study dataset.
The first holds permitted case inputs; the second holds expected labels and transport/reference relations.
Keep expected answers out of analysis input. This is a functional test rule, not a private-data service.
`bench_evaluate_micro_cohort()` and existing tests retain their current signatures and behavior.
The generator's synthetic cases and prose provider are not required for the public research path.

`bench_allele_transport_metrics()`, `bench_genotype_transport_metrics()` and
`bench_hpo_metrics()` remain available on their declared schemas.
`bench_classification_diff()` compares caller-provided RClinVarbitration decisions.
New public temporal selection and the complete VariantStory adapter still require implementation.
See [ARCHITECTURE.md](ARCHITECTURE.md) for responsibilities.
