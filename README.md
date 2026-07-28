
# VariantStoryBench

[![R-CMD-check](https://github.com/RGenomicsETL/VariantStoryBench/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/RGenomicsETL/VariantStoryBench/actions/workflows/R-CMD-check.yaml)

VariantStoryBench generates small sealed GRCh38 benchmark inputs and
evaluates declared rare-disease prioritisation results against separate
evaluator truth. It does not implement a prioritiser, generic command
runner, workflow framework, or source ingestion/provenance system.

[ARCHITECTURE.md](ARCHITECTURE.md) states the current package
responsibilities and [benchmark-contract.md](benchmark-contract.md)
defines executable relations, coordinate conventions, and metric
denominators.

## Install

``` r
remotes::install_github("RGenomicsETL/VariantStoryBench")
```

## Generate sealed inputs and evaluator truth

The generator writes causal singleton, trio, symbolic-CNV, and
phenotyped confirmed-negative VCFs with `vcfppR`. The engine-facing
bundle contains only VCFs, GRCh38 generations, persons with exact VCF
sample IDs, family presentation, and clinical documents. `persons` has
`case_id`, `person_id`, `vcf_sample_id`, `is_proband`, `sex`, and
`affected`; `relationships` uses `case_id`, `person_id`, `relative_id`,
and `relationship`. The evaluator-only bundle contains causal answers
and latent observations. No reference result or oracle is supplied.

The generated records use Ensembl GRCh38 primary-assembly contig names
and these verified reference alleles:

| VCF locus         | REF   | ALT                     |
|:------------------|:------|:------------------------|
| `1:100000`        | `C`   | `T`                     |
| `1:100100-100102` | `TGC` | `TC` (canonical `TG>T`) |
| `2:199999-200000` | `TG`  | `T`                     |
| `2:200100`        | `T`   | `A`                     |
| `2:200200`        | `A`   | `C`                     |
| `2:200300`        | `T`   | `C`                     |
| `7:549997`        | `T`   | `<DEL>` (`END=559997`)  |

These micro-coordinates were checked against Ensembl release 116 GRCh38
primary assembly. The reference FASTA is not bundled with the package.

``` r
library(VariantStoryBench)

bundle <- bench_generate_micro_cohort(tempfile("variantstorybench-micro-"))
paste(names(bundle$engine_input), collapse = ", ")
#> [1] "case_manifest, generations, vcf_paths, persons, relationships, documents"
paste(names(bundle$evaluator_truth), collapse = ", ")
#> [1] "cases, truth, documents, hpo_observations, inheritance_truth, allele_truth, genotype_truth, causal_allele_truth, cnv_truth, capabilities"
bundle$engine_input$generations[, c("generation_id", "assembly", "case_design")]
#>                  generation_id assembly  case_design
#> 1          micro-singleton-vcf   GRCh38    singleton
#> 2               micro-trio-vcf   GRCh38         trio
#> 3       micro-symbolic-cnv-vcf   GRCh38 symbolic_cnv
#> 4 micro-confirmed-negative-vcf   GRCh38    singleton
```

A text provider receives only a case ID, HPO/context presentation, and
family relationships. It must return valid source text for every case,
including an empty phenotype plan, and zero-based half-open spans for
every presented HPO observation. The CNV note therefore has zero
observations. It never receives causal truth.

``` r
provider <- function(presentation) {
  # Call a configured gpt-5.3-spark or Rbebelm provider outside this package.
  terms <- presentation$phenotype_plan
  source_text <- if (nrow(terms)) {
    paste(terms$hpo_id, collapse = "; ")
  } else {
    "No phenotype terms were supplied."
  }
  starts <- vapply(terms$hpo_id, function(id) {
    regexpr(id, source_text, fixed = TRUE)[[1L]] - 1L
  }, integer(1))
  list(source_text = source_text, spans = data.frame(
    hpo_id = terms$hpo_id,
    context_status = terms$context_status,
    start_offset = starts,
    end_offset = starts + nchar(terms$hpo_id)
  ))
}
```

Each source document has `case_id`, `document_id`, and `source_text`;
there is one document and one proband for every case. Generated
evaluator observations wrap `case_id`, `person_id`, and `observation_id`
around the unchanged canonical `ducksemantics` fields: `document_id`,
`hpo_id`, exact source span/text, `context_status`, method, provider
provenance, confidence, and accepted status. The wrapper prevents a
relative’s finding from being scored as the proband’s; document
text/span semantics remain owned by ducksemantics. Negated findings are
`absent/negated`.

``` r
bench_hpo_metrics(
  bundle$evaluator_truth$documents,
  bundle$evaluator_truth$hpo_observations,
  bundle$evaluator_truth$hpo_observations
)[, c("term_recall", "context_recall", "span_recall")]
#>   term_recall context_recall span_recall
#> 1           1              1           1
```

## Declared engine results

There is currently no bundled engine adapter. A caller may run a
concrete sealed adapter outside the package, passing only
`bundle$engine_input`, then supply declared `runs`, `evaluations`, and
`candidates` to evaluation with `bundle$evaluator_truth`.

``` r
metrics <- bench_evaluate_micro_cohort(
  bundle$evaluator_truth,
  runs,
  evaluations,
  candidates
)
```

Ranks are unique and contiguous per run/case/target, with score ties
broken by candidate ID. Failed, skipped, and unsupported known-causal
units remain ranking misses. Source spans are strictly nonempty
zero-based half-open intervals.

A frequency-capable adapter may additionally emit the narrow typed
case-frequency relation validated by
`bench_validate_frequency_observations()`. The validator keeps absent
rows, unlocalized shards, provider conflicts, filtering, missing values,
AC=0/AN\>0, and AN=0 distinct; it requires lowercase 16-character
hexadecimal VariantKey text, checks AC/AN/AF and FAF bounds and
missingness, and never assigns PM2. The broad provider pack is not a
benchmark output.

## Sealed scientific truth relations

The evaluator-only bundle retains source/canonical `allele_truth`,
person-grain `genotype_truth`, explicit `causal_allele_truth`,
`inheritance_truth`, and `cnv_truth` as sealed relations.
`bench_allele_transport_metrics()` compares source and canonical GRCh38
geometry plus source admission by record/ALT ordinal.
`bench_genotype_transport_metrics()` compares GT, GQ, DP, ALT-relative
copy count, ploidy, phase/phase set, and ALT-relative call state without
applying a GQ threshold. `causal_allele_truth` separately marks source
`reference` versus one exact `alternate` ordinal: the singleton causal
answer intentionally targets REF, while the confirmed-negative case has
a called ALT and no causal row. Thus REF/ALT and call state never stand
in for pathogenic/benign orientation. These truth relations are not sent
to an engine or text provider.

The symbolic deletion is a real `cnv` case with GRCh38, type, BED
interval, source `unsupported_symbolic` admission, and separate
`routed`/`XCNV` routing truth. VCF `POS=549997` is the one-based
padding/base-before-event coordinate, while `END=559997` is the
inclusive last affected base. Excluding the padding base gives the
affected BED half-open interval `[549997, 559997)`: use VCF `POS` as the
BED start and `END` as the exclusive end. This is a 10,000 bp affected
interval. The VCF itself remains unchanged. Exact GQ and DP are genotype
transport truth, not evidence-policy thresholds.

The capability relation explicitly marks realistic exome/genome
simulation, related ancestry/admixture, multiplex/consanguinity, general
CNV/SV, and novel gene-disease historical holdouts as unsupported.

## Temporal status

Executable temporal selection is not implemented. The selected
first-release design uses provider-specific availability epochs
(`2024-01-23` and `2026-07-21`), a ReVUS-aligned ClinVar transition
track, case reanalysis, PM5 first-seen evidence, and receipt-bound
case-document authoring. See
[`temporal-benchmark.md`](temporal-benchmark.md).
`bench_classification_diff()` remains available for a caller-provided
fixed-policy comparison of two RClinVarbitration decisions; generic
anti-join counts are not accepted as proof.

## Pipeline

[`targets`](https://docs.ropensci.org/targets/) generates separate
engine-input and evaluator-truth targets and validates their contracts.
It does not invent engine output.

``` r
targets::tar_make(callr_function = NULL)
```

## Licence

GPL-3. See `DESCRIPTION`.
