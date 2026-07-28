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
| Evaluator truth | Causal answers with explicit REF/ALT role, person-grain identity around canonical HPO observations, source/canonical allele truth, exact genotype transport truth, CNV truth, and capability rows | Engine access and clinical evidence policy |
| Clinical prose | Call a supplied provider with phenotype/context and family presentation only | Prompt/model configuration, including gpt-5.3-spark or Rbebelm |
| Evaluation | Validate declared relations, including typed case-frequency observations, and calculate explicit-denominator metrics | Clinical adjudication |

## Sealed data flow

`bench_generate_micro_cohort()` returns two deliberately separate bundles:

1. `engine_input`: `case_manifest`, VCF paths/generation rows, `persons`,
   relationships, and source documents. `persons` has exactly
   `case_id`, `person_id`, `vcf_sample_id`, `is_proband`, `sex`, and `affected`
   (with admitted `affected`/`unaffected`/`unknown` values);
   every VCF sample is admitted through that mapping. It has no causal answer,
   truth, reference, or oracle relation.
2. `evaluator_truth`: cases, causal truth, case/person/observation identity
   around canonical `ducksemantics` HPO fields, source/canonical `allele_truth`,
   person-grain `genotype_truth`, explicit `causal_allele_truth`, CNV truth, and
   capabilities. It is not passed to the
   prose provider or an engine.

`bench_evaluate_micro_cohort()` accepts only `evaluator_truth` and declared
`runs`, `evaluations`, and `candidates`. No reference result is generated.
There is currently no bundled engine adapter: execution remains unsupported
until a concrete adapter accepts the complete `engine_input` bundle and emits
validated result relations. The public
`bench_validate_frequency_observations()` contract can validate an adapter's
case-frequency output without loading VariantStory or rebuilding its provider
fixture. It keeps provider-row multiplicity and match/filter/observation state
explicit; it is not a PM2 evaluator.

## Current synthetic scope

The generator writes a singleton VCF, a trio indel VCF with all three
sample rows for every record, a symbolic deletion VCF, and a phenotyped
confirmed-negative singleton VCF. Relationships use
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
| `1:100100-100102` | `TGC` | `TC` (canonical `TG>T`) |
| `2:199999-200000` | `TG` | `T` |
| `2:200100` | `T` | `A` |
| `2:200200` | `A` | `C` |
| `2:200300` | `T` | `C` |
| `7:549997` | `T` | `<DEL>` (`END=559997`) |

These micro-coordinates were checked against Ensembl release 116 GRCh38
primary assembly. The package does not bundle the reference FASTA or provide a
general reference validator.

For the symbolic deletion, VCF `POS=549997` is the one-based padding/base-before-event
coordinate and `END=559997` is the inclusive last affected base. The padding base
is excluded from the affected span, so the BED half-open interval is
`[549997, 559997)`: use VCF `POS` as the BED start and `END` as the exclusive
end. This affected interval is `559997 - 549997 = 10,000` bp; the VCF itself
remains unchanged.

Every case emits one source document with `case_id`, including the CNV case
whose phenotype plan is empty and whose observation count is zero. Evaluator
HPO rows add `case_id`, `person_id`, and `observation_id` around unchanged
canonical `ducksemantics` fields. The text provider receives no causal truth;
metrics retain person grain so findings cannot move silently between relatives.

`allele_truth` is keyed by case/source-record/ALT ordinal and preserves exact
source and expected canonical GRCh38 geometry, sequence class, and admission
status. The `TGC>TC` fixture is canonically suffix-minimized to `TG>T` without
requiring a reference lookup. `genotype_truth` adds person grain and preserves
exact GT, GQ, DP, ploidy, phase, and call state; its call state is one of
`called_alternate`, `called_reference`, `partial_no_call`, `no_call`, or
`other_alternate`. These are call states relative to an ALT ordinal, not
clinical-significance labels. `causal_allele_truth` separately identifies
whether variant causal truth targets source `reference` or one exact
`alternate` ordinal. The singleton causal answer intentionally targets REF;
the confirmed-negative case has a called ALT but no causal row. Public
transport metrics compare engine-neutral relations with sealed truth. GQ/DP
are not interpreted as a Bench quality threshold. The inheritance and CNV
truth relations remain sealed for future scientific evaluation.

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
