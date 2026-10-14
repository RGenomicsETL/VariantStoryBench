# Public-data evaluation plan

Status: selected project direction; source preparation, engine adapters, and study runs remain planned.

VariantStoryBench is the public evaluation companion to
[VariantStory PR #7](https://github.com/RGenomicsETL/VariantStory/pull/7).
Use public data throughout this work.
Publish the source inventory, selection rules, labels, configuration, evaluation scripts,
and results together in this repository.
The study must be reproducible from the declared public sources without individual access approval.

Existing generated micro-cohorts remain developer fixtures.
They are not the study population and do not gate delivery of this public-data plan.
Do not add a study dependency on case generation or a private cohort.

## Independent public tracks

| Track | Source requirements | Output |
|---|---|---|
| Transport and scale | Public GIAB or IGSR calls, exact assembly/reference, sample mappings, and benchmark regions | Transport checks, query/ingest measurements, and replay |
| Known-gene prioritization | Public case records with usable genotype or candidate data, phenotype observations, and published causal labels | Ranks, review burden, coverage, and supported recovery metrics |
| Public evidence changes | Public provider artifacts at declared releases and availability cutoffs | Changed assertions/classifications and concordance results |
| Temporal case reanalysis | Eligible public case inputs plus before/after provider evidence | Incremental/full equality and case-level changes |

Select exact datasets before starting each experiment.
Start transport and provider-release work without waiting for the case-source inventory.
Public callsets without disease diagnoses support technical evaluation, not diagnostic recovery.
Do not invent phenotypes, genotypes, or candidate backgrounds to fill missing case fields.
Keep gene-only, candidate-list, exome/genome, and phenotype-only benchmarks distinct.
Report missing or ineligible fields in the source inventory.

## Source inventory

Publish one manifest with, at minimum:

| Field group | Required information |
|---|---|
| Identity | Dataset, source URL/accession, release, and exact artifact |
| Reuse | Public access route, license/reuse terms, permitted redistribution |
| Genomics | Assembly/reference, available call fields, sample/person mappings |
| Case scope | Phenotype and pedigree fields, causal-label source, candidate universe |
| Time | Source availability, case-input eligibility, provider cutoffs |
| Selection | Included units, exclusions, missing fields, development/evaluation split |

Public access does not imply permission to redistribute raw data.
Commit preparation scripts and permitted small metadata; keep large downloads outside Git.
Publish reproducible retrieval instructions when raw artifacts remain at their original source.
Do not publish identifying information or unlicensed clinical text.

## Public data flow

```text
public source manifest + preparation scripts
    -> declared case inputs + eligible provider releases
    -> VariantStory adapter
    -> runs / evaluations / candidates
    -> result validation and metrics
    -> public run report and reproducible result tables

public labels + source-selection code
    -> evaluator after engine execution
```

All study labels and selection rules are public.
Labels remain separate from the engine's case inputs and ranking evidence.
This is evaluation discipline, not a requirement for a private dataset or hosted evaluation service.
The engine must not consume causal answers as input features.
Record overlap between label sources and provider evidence.
An assertion reused as input and target supports concordance, not independent recovery.

## Reuse current contracts

Use the result validators and metrics in `R/` and the declared
[`benchmark-contract.md`](benchmark-contract.md) schemas.
Do not require public datasets to come from `bench_generate_micro_cohort()`.
Retain the generator and its tests for developer checks without changing their current runtime behavior.
Add public-data adapters to the existing relation contracts rather than creating another benchmark engine.

The first VariantStory adapter uses ordinary DuckDB relations and the current R policy.
It emits declared `runs`, `evaluations`, and `candidates`.
The same adapter contract later accepts VariantLake data.
No custom file format or complete lake runtime is required for the first public run.

## Temporal protocol

Use the source-availability and fixed-policy comparison rules in
[`temporal-benchmark.md`](temporal-benchmark.md) where they apply to the selected public artifacts.
Record exact before/after cutoffs and available archives before execution.
Do not infer historical availability from a downloaded file's timestamp.
Do not generate case narratives or phenotypes for this study.
Case descriptions must not disclose later diagnoses to earlier-time evaluations.

Hold policy fixed while changing provider releases.
Hold releases fixed while changing policy.
Compare complete incremental output with a full run on identical inputs.
Keep unchanged findings with their lineage; failed attempts cannot publish partial completed results.

## Delivery sequence

| Step | Reviewable artifact | Acceptance check |
|---|---|---|
| 1. Source inventory | Public manifest and eligibility report | Each included unit has reproducible inputs and appropriate reuse terms |
| 2. Preparation | R/SQL scripts and validation queries | Source identities and declared missing fields survive preparation |
| 3. Engine adapter | Declared input/result mappings | Outputs pass validators; labels are absent from engine inputs |
| 4. First comparisons | Public callset and provider-release runs | Results, failures, versions, and resource costs are reported |
| 5. Case reanalysis | Eligible public cases and pinned evidence updates | Complete incremental results equal full reanalysis |
| 6. Report | Manifests, outputs where permitted, tables, and limitations | Another user can reproduce each reported result |

Publish corresponding implementation PRs in VariantStory and VariantStoryBench at each step.
The first case example includes an affected and an unaffected case.
Use ordinary failure-injection tests to verify publication behavior, not as research cases.

## Claims and implementation status

Report top-k recovery only with a supported causal target and candidate universe.
Report unsupported units, failures, abstention, and coverage in declared denominators.
An unresolved case is not a confirmed negative.
Report review burden, evidence changes, replay, runtime, memory, and bytes read/written.
Public reference-callset checks and provider concordance do not establish clinical diagnostic yield.

The package already has relation validators, metrics, and developer fixture generation.
Public-source preparation, the bundled VariantStory adapter, and executable temporal selection still need implementation.
This plan changes documentation only; it does not announce a completed benchmark.
Behavior changes require focused tests and NEWS entries.
