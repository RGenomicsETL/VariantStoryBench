# VariantStoryBench relation and metric contract

**Current executable authority:** validators and metrics in `R/`, with
regressions in `inst/tinytest/`. [ARCHITECTURE.md](ARCHITECTURE.md) defines the
package boundary.

## Sealed generation bundles

`bench_generate_micro_cohort()` returns two bundles. They are separate
admission boundaries, not two views of one engine payload.

| Bundle | Relations | Contract |
|---|---|---|
| `engine_input` | `case_manifest`, `generations`, `vcf_paths`, `persons`, `relationships`, `documents` | Contains only GRCh38 VCFs and family/clinical presentation. It must not contain causal IDs, evaluator truth, a reference result, or an oracle. |
| `evaluator_truth` | `cases`, `truth`, `documents`, `hpo_observations`, `inheritance_truth`, `sequence_truth`, `cnv_truth`, `capabilities` | Kept outside provider and engine input. It is supplied only to evaluation. |

The text provider receives only `case_id`, `phenotype_plan` (`hpo_id` and
`context_status`), and relationships. It never receives causal variant or gene
truth. It returns valid `source_text` plus exact HPO spans; an empty phenotype
plan is valid and produces a document with zero observations. The source
document and canonical HPO observations are then independently validated.

There is no bundled engine adapter or reference result. A concrete adapter is
admissible only when it consumes the complete `engine_input` bundle and emits
validated core result relations.

## Core result relations

| Relation | Required identity | Contract |
|---|---|---|
| `cases` | `case_id`, `target_type` | `truth_status` is `known_causal`, `unresolved`, or `confirmed_negative`; `target_type` includes `cnv`. |
| `truth` | `case_id`, `target_type`, `causal_id` | Only known-causal units have truth; every known-causal unit has at least one row. |
| `runs` | `run_id` | Declares engine/version/source/profile/cutoff/resources and run status. |
| `evaluations` | `run_id`, `case_id`, `target_type` | Contains exactly one row for every run × case unit; status is completed, failed, unsupported, or skipped. |
| `candidates` | run/case/target/candidate | Candidates belong only to completed evaluations. Ranks are unique and contiguous from 1 per emitted case unit; emitters break score ties by `candidate_id`. |
| `judgments` / `judgment_sources` | claim key / source key | Directional judgments cite matching source stance. Present spans are zero-based, half-open, and strictly nonempty. |

`bench_rank_metrics()` includes failed, skipped, and unsupported known-causal
units as misses. It reports unresolved and confirmed-negative burden
separately. `bench_grounding_metrics()` is source-audit coverage, not evidence
correctness.

## Persons, relationships, documents, and HPO observations

`persons` has exactly `case_id`, `person_id`, `vcf_sample_id`, `is_proband`,
`sex`, and `affected`; `affected` uses `affected`, `unaffected`, or `unknown`.
Every generation's VCF sample header must equal the
case's `persons$vcf_sample_id` values; every case has exactly one proband.
`relationships` has exactly `case_id`, `person_id`, `relative_id`, and
`relationship`. The trio uses two `biological_parent` edges; sex distinguishes
those parents in `persons`.

`documents` has `case_id`, unique `document_id`, and exact nonempty
`source_text`, with one document for every case, including CNV.
`hpo_observations` adds the evaluator wrapper

```
case_id, person_id, observation_id
```

around exactly `ducksemantics_hpo_observation_contract()`:

```
document_id, hpo_id, start_offset, end_offset, source_text,
context_status, method, provider_id, provider_version, confidence, status
```

Every observation refers to a document in the same case and to a declared
person. `ducksemantics_hpo_observations()` validates document identity, exact quoted
`source_text`, zero-based half-open bounds, accepted status, and canonical
context vocabulary. Negated findings use `absent/negated`, not `negated`.

`bench_hpo_metrics(documents, truth, extracted, extracted_documents)` validates
both observation relations against their source documents and scores term,
context, and exact span separately at case/person grain. A zero denominator is reported with count
zero and `NA` rates; it is unavailable, not a perfect score. When precision
and recall both have present denominators and equal zero performance, F1 is
zero rather than `NA`.

## Generated GRCh38 cohort

| Relation | Current contract |
|---|---|
| `generations` | One singleton, trio, and symbolic-CNV GRCh38 VCF written through `vcfppR`. |
| `persons` | Singleton, all trio members, and the CNV proband, with exact VCF sample mappings. |
| `relationships` | Latent trio presentation with two `biological_parent` edges. |
| `sequence_truth` | Person-grain SNV/indel/CNV rows for every sample/record, retaining sequence class and genotype call status. |
| `cnv_truth` | `case_id`, assembly, contig, CNV type, BED start/end, and authority. |
| `capabilities` | Explicit `supported` or `unsupported` status and detail. |

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

The symbolic deletion is an actual `cnv` case in `cases`, `truth`, and emitted
`evaluations`. Its VCF `POS=549997` is the one-based padding/base-before-event
coordinate, and `END=559997` is the inclusive last affected base. Exclude the
padding base when converting to the BED half-open affected interval:
`[549997, 559997)` (use VCF `POS` as the BED start and `END` as the exclusive
end). The affected interval is exactly `559997 - 549997 = 10,000` bp. The VCF
remains unchanged. The sealed CNV truth retains assembly, type, contig,
exact interval, and authority for future scientific evaluation; no current
public metric interprets it and it never scores opaque CNV IDs.

The cohort has a causal singleton SNV, a causal trio indel across every sample
row, benign distractors, no-call contrasts, and the separately
typed symbolic CNV. It does **not** simulate realistic exome/genome,
ancestry/admixture, multiplex/consanguinity, general CNV/SV, or novel
gene-disease historical holdouts; each has an explicit unsupported capability
row.

## Other metrics and temporal status

The sealed `sequence_truth`, `inheritance_truth`, and `cnv_truth` relations are
retained for future scientific evaluation. `sequence_truth` is keyed by
`case_id`, `person_id`, and `record_id`, with `sequence_class` and `call_status`
truth; the inheritance and CNV relations retain their declared structural
fields and authorities. No current public metric interprets these relations.
Raw GQ and DP remain only in generated VCF input, and the package applies no
GQ threshold.

Temporal case selection is unsupported. `bench_classification_diff()` remains
a comparison over caller-provided `RClinVarbitration` decision relations with a
fixed policy per release comparison. This package does not execute source
snapshot anti-joins and does not accept a generic match count as proof.

`_targets.R` generates separated input/truth bundles and validates their
contracts. It does not fabricate candidate results or run an unspecified
engine.
