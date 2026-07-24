
# VariantStoryBench

[![R-CMD-check](https://github.com/RGenomicsETL/VariantStoryBench/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/RGenomicsETL/VariantStoryBench/actions/workflows/R-CMD-check.yaml)

VariantStoryBench is an R package for reproducible rare-disease variant
reanalysis benchmarks. It validates explicit case, truth, run, coverage,
and candidate manifests; calculates ranking and candidate-burden
metrics; and provides an S7 adapter contract for running declared
external engines.

## Install

``` r
remotes::install_github("RGenomicsETL/VariantStoryBench")
```

## Comparable ranking metrics

The bundled fixture executes the same contract used for real runs. A
failed or unsupported known-causal case remains a miss. An unresolved
case is reported as unresolved candidate burden, not treated as a
negative control.

``` r
library(VariantStoryBench)

fixture <- function(name, kind) {
  bench_read_manifest(
    system.file("extdata", name, package = "VariantStoryBench"),
    kind
  )
}

metrics <- bench_rank_metrics(
  cases = fixture("benchmark-cases.csv", "cases"),
  truth = fixture("benchmark-truth.csv", "truth"),
  runs = fixture("benchmark-runs.csv", "runs"),
  evaluations = fixture("benchmark-evaluations.csv", "evaluations"),
  candidates = fixture("benchmark-candidates.csv", "candidates"),
  top_k = c(1L, 3L)
)

metrics[, c(
  "run_id", "target_type", "case_count", "completed_case_count",
  "known_causal_case_count", "top_1_recall", "top_3_recall",
  "mean_candidate_burden"
)]
#>           run_id target_type case_count completed_case_count
#> 1 fixture-a-2026        gene          1                    1
#> 2 fixture-a-2026     variant          4                    4
#> 3 fixture-a-2026 variant_set          1                    1
#> 4 fixture-b-2026        gene          1                    0
#> 5 fixture-b-2026     variant          4                    3
#> 6 fixture-b-2026 variant_set          1                    1
#>   known_causal_case_count top_1_recall top_3_recall mean_candidate_burden
#> 1                       1          1.0          1.0              1.000000
#> 2                       2          0.5          1.0              1.500000
#> 3                       1          0.0          1.0              2.000000
#> 4                       1          0.0          0.0                    NA
#> 5                       2          0.0          0.5              1.666667
#> 6                       1          1.0          1.0              1.000000
```

The earlier compact `bench_read_results()` and `bench_metrics()` API
remains available for simple one-engine summaries. New comparative work
should use the relational manifest contract above.

## Temporal ClinVar decisions

ReVUS makes release-to-release classification change a benchmark target.
RClinVarbitration adds a second useful axis: named submitter-exclusion
policy. VariantStoryBench compares one axis at a time. A temporal
comparison fixes the policy receipt; a policy-sensitivity comparison
fixes the ClinVar release.

``` r
changes <- bench_classification_diff(
  disease_decisions,
  left_release = "2022-06",
  left_policy = "cpg-2.2.11/default",
  right_release = "2026-07",
  right_policy = "cpg-2.2.11/default"
)

bench_classification_diff_summary(changes)
```

The comparison stays disease-level. It does not erase condition-specific
evidence by reducing every allele to one label.

RClinVarbitration exports the canonical source-rich disease-decision
Parquet, including stable record keys, complete-row content receipts,
and nested SCV and RCV receipts. Register the Parquet, merge changed
keys into the persistent DuckLake table, and obtain the exact changed
rows with `ducklake::get_table_changes()`. `bench_classification_diff()`
remains the engine-neutral benchmark summary over those declared
snapshots; it does not reparse ClinVar, redefine SCV identity, or
implement another snapshot engine.

## Source-backed retrieval and judgments

Phenotype, disease, literature, and gene-discovery retrieval is
evaluated separately from candidate ranking. Embeddings and late
interaction may retrieve candidate genes or analogous cases. A
deterministic rule or local LLM may then judge a phenotype, inheritance,
or mechanism claim, but every emitted judgment must identify the exact
source relation, release, record, field, and, for narrative text, the
exact span. If no source was retrieved, the engine abstains instead of
manufacturing evidence.

``` r
judgments <- fixture("benchmark-judgments.csv", "judgments")
judgment_sources <- fixture(
  "benchmark-judgment-sources.csv", "judgment_sources"
)
candidates <- fixture("benchmark-candidates.csv", "candidates")

bench_grounding_metrics(judgments, judgment_sources, candidates)
#>           run_id grounded_candidate_count judgment_count supports_count
#> 1 fixture-a-2026                        1              2              1
#>   contradicts_count insufficient_evidence_count mean_sources_per_judgment
#> 1                 0                           1                       1.5
#>   unique_source_record_count
#> 1                          3
```

ClinVar contributes disease-level assertions and linked publications; it
is not treated as a complete phenotype-rich solved-case corpus. Public
case reports, curated solved cases, gene-disease/mechanism sources, and
permitted historical cases remain distinct source relations. The
grounding summary measures audit coverage only. Scientific relevance,
source-attribution precision, and judgment accuracy require separately
adjudicated truth.

## Benchmark programme

The public benchmark separates:

- deterministic software fixtures;
- causal-event spike-ins in declared GIAB or 1000 Genomes backgrounds;
- temporal holdouts such as ReVUS;
- held-out public solved cases;
- controlled clinical evaluation inside the approved data environment.

Variant, phased variant-set, and gene targets are scored separately. A
gene-discovery stratum must use a historical knowledge cutoff so the
candidate gene was absent from the engine’s admitted gene-disease and
training sources. Talos’s established-disease-gene scope is compared as
its own profile rather than counted as a failure on a task it does not
claim to perform.

The complete [benchmark contract](benchmark-contract.md) defines the
relations, denominators, comparator rules, public/private data split,
and the evidence that can credibly support the July 30 milestone.

## External engines

`BenchCommandAdapter` uses `blit` to run an executable with declared,
quoted arguments. `{input}` and `{output}` are substituted before
execution. `BenchRunner` is the S7 contract accepted by consumers of
adapters.

``` r
adapter <- BenchCommandAdapter(
  executable = "my-prioritizer",
  arguments = c("--input", "{input}", "--output", "{output}")
)

run <- bench_execute(adapter, "case.vcf", "benchmark-output/case.csv")
stopifnot(run@status == 0L)
```

## Pipeline

The repository contains a
[`targets`](https://docs.ropensci.org/targets/) pipeline over the
packaged synthetic manifest.

``` r
# From the package source directory:
targets::tar_make(callr_function = NULL)
```

The bundled fixture is synthetic. Add public or redistributable fixtures
with their source, version, knowledge cutoff, and licence recorded
alongside the data. Private VariantStory code and clinical data stay
outside this public repository.

## Licence

GPL-3. See `DESCRIPTION`.
