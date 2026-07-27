# VariantStoryBench architecture

**Current authority:** the relation validators and metrics in `R/`, exercised by
`inst/tinytest/`. This document states current boundaries, not a delivery plan.

VariantStoryBench generates small synthetic GRCh38 benchmark inputs and keeps
evaluator truth separate. It validates declared result relations and calculates
metrics. `targets` orchestrates generation and contract checks. The package
does not implement a diagnostic prioritiser, a workflow framework, generic
command execution, production source semantics, source provenance/checksums,
or a ClinVar/literature/Monarch loader.

| Boundary | Package responsibility | Outside this package |
|---|---|---|
| Engine input | GRCh38 VCF paths/generations, persons with exact VCF sample IDs, case/relationship presentation, and clinical source documents | A concrete engine adapter and its output parser |
| Evaluator truth | Causal answers, canonical HPO observations, sequence/CNV truth, and capability rows | Engine access and clinical evidence policy |
| Clinical prose | Call a supplied provider with phenotype/context and family presentation only | Prompt/model configuration, including gpt-5.3-spark or Rbebelm |
| Evaluation | Validate declared relations and calculate explicit-denominator metrics | Clinical adjudication |

## Sealed data flow

`bench_generate_micro_cohort()` returns two deliberately separate bundles:

1. `engine_input`: `case_manifest`, VCF paths/generation rows, `persons`,
   relationships, and source documents. `persons` has exactly
   `case_id`, `person_id`, `vcf_sample_id`, `is_proband`, `sex`, and `affected`
   (with admitted `affected`/`unaffected`/`unknown` values);
   every VCF sample is admitted through that mapping. It has no causal answer,
   truth, reference, or oracle relation.
2. `evaluator_truth`: cases, causal truth, canonical `ducksemantics` HPO
   observations, sequence/CNV truth, and capabilities. It is not passed to the
   prose provider or an engine.

`bench_evaluate_micro_cohort()` accepts only `evaluator_truth` and declared
`runs`, `evaluations`, and `candidates`. No reference result is generated.
There is currently no bundled engine adapter: execution remains unsupported
until a concrete adapter accepts the complete `engine_input` bundle and emits
validated result relations.

## Current synthetic scope

The generator writes a singleton SNV VCF, a trio indel VCF with all three
sample rows for every record, and a symbolic deletion VCF. Relationships use
`case_id`, `person_id`, `relative_id`, and `relationship`; both trio edges are
`biological_parent`, with parent sex carried by `persons`. The deletion is a
real `cnv` case with a mapped CNV proband, GRCh38, type, BED half-open interval,
and `XCNV` authority. It is a transport fixture, not general CNV/SV
simulation.

The generated VCFs use Ensembl GRCh38 primary-assembly contig names and these
verified reference alleles:

| VCF locus | REF | ALT |
|:--|:--|:--|
| `1:100000` | `C` | `T` |
| `1:100100` | `T` | `G` |
| `2:199999-200000` | `TG` | `T` |
| `2:200100` | `T` | `A` |
| `2:200200` | `A` | `C` |
| `2:200300` | `T` | `C` |
| `7:549997` | `T` | `<DEL>` (`END=559997`) |

These micro-coordinates were checked against Ensembl release 116 GRCh38
primary assembly. The package does not bundle the reference FASTA or provide a
general reference validator.

Every case emits one source document with `case_id`, including the CNV case
whose phenotype plan is empty and whose observation count is zero. Canonical
`ducksemantics` observations remain unchanged and link to a case only through
`documents`; the text provider receives no causal truth.

Sequence truth is keyed by `case_id`, `person_id`, and `record_id`. Its
`call_status` is one of `called_alternate`, `called_reference`,
`partial_no_call`, `no_call`, or `other_alternate`; `quality_status` separately
uses `pass`, `low_quality`, or `unavailable`. The fixture uses GQ >= 20 as pass,
finite GQ < 20 as low quality, and missing GQ as unavailable. Strict sequence
metrics include both dimensions.

The `capabilities` relation marks realistic exome/genome simulation, related
ancestry/admixture, multiplex/consanguinity, general CNV/SV, and novel
gene-disease historical holdouts as `unsupported`.

## Temporal selection

Release-pinned ClinVar and source-snapshot/anti-join temporal selection are
**unsupported** here. The package retains the existing
`bench_classification_diff()` comparison over caller-provided decisions, but
does not accept a caller-supplied anti-join count as proof. A temporal
benchmark requires executable source relations before it can be measured.

See [benchmark-contract.md](benchmark-contract.md) for relation schemas,
coordinate conventions, and metric denominators.
