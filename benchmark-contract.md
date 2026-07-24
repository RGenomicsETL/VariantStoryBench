# VariantStoryBench benchmark contract

Status: current implementation guidance for the public benchmark package.

## What the benchmark measures

VariantStoryBench compares complete rare-disease prioritisation runs, not one
annotation field or one pathogenicity score. The public contract has five core
ranking relations and two source-grounding relations:

| Relation | Unit |
|:--|:--|
| cases | one case and evaluation target: variant, variant set, or gene |
| truth | one accepted causal answer; a case may have more than one |
| runs | one engine, profile, source revision, knowledge cutoff, and resource receipt |
| evaluations | one explicit completion, failure, unsupported, or skipped status for every run and case unit |
| candidates | one ranked candidate emitted by a completed evaluation |
| judgments | one declared phenotype, inheritance, mechanism, disease, or literature claim about a candidate |
| judgment_sources | one exact source record, field, optional text span, and stance cited for a judgment |

Known-causal, unresolved, and confirmed-negative cases are different states.
An unresolved case is not a negative control. A failed or unsupported
known-causal case remains in recall denominators instead of disappearing.

`bench_rank_metrics()` reports top-k recall and mean reciprocal rank over
known-causal units, candidate burden over completed units, explicit execution
coverage, and separate unresolved and confirmed-negative burdens. Variant,
variant-set, and gene targets remain separate by default.

`bench_validate_grounding()` requires every judgment to cite at least one exact
source record. Directional judgments require a source with the same
`supports` or `contradicts` stance. An `insufficient_evidence` judgment may
cite contextual or conflicting records. If retrieval finds no source, the
engine abstains instead of emitting an unsupported judgment.

`bench_grounding_metrics()` reports judgment and source counts as audit
coverage. It does not claim that a citation is relevant or a judgment is
correct. Source-attribution precision, support/contradiction accuracy, and
calibrated abstention require separately adjudicated truth.

## RGenomicsETL stack under test

| Component | Benchmark role |
|:--|:--|
| DuckHTS/Rduckhts | VCF/BCF/gVCF and SV transport, DuckVEP consequence/HGVS facts, dense and interval annotation readers |
| RClinVarbitration | release-pinned ClinVar source relations, disease-level decisions, and named submitter-exclusion policies |
| ducksemantics | deterministic ontology graph operations plus declared phenotype and literature retrieval candidates |
| Rbebelm | optional local HPO/text proposal and reranking provider, measured separately from deterministic grounding |
| VariantStory | private case, evidence, policy, prioritisation, review, and report implementation |
| VariantStoryBench | public fixtures, comparator adapters, run receipts, metrics, and publication protocol |

An Rbebelm or ducksemantics result may propose a candidate. It is not admitted
clinical evidence and does not become a correct gene merely because it ranks
high. ClinVar assertions are not treated as complete phenotype-rich cases:
disease decisions, linked literature, curated solved cases, gene-disease
evidence, and governed historical cases remain separately identified sources.
Gene discovery needs the historical holdout described below.

Bulk source preparation belongs in `targets`. Validated source and result
relations can be published as DuckLake snapshots and queried in DuckDB.
Snapshot identity, source-effective date, and engine knowledge cutoff are all
recorded: a recent snapshot containing an old source release is not equivalent
to a historical as-of run. Public resources and protected clinical relations
use separate catalogs and storage.

## Evidence programme

The benchmark grows through distinct evidence products. Results from one
product must not be relabelled as another.

1. **Executable fixtures.** Small examples cover evidence codes, inheritance,
   phase, missingness, conflicts, CNV/SV, and update semantics.
2. **Public background spike-ins.** Causal events are introduced into declared
   GIAB or 1000 Genomes backgrounds. Trio, duo, and singleton presentations
   isolate the value of pedigree information. These measure analytical
   recovery, not clinical yield.
3. **Temporal holdouts.** An engine sees only sources available at the declared
   knowledge cutoff and is scored against later changes. ReVUS and Genome
   Alert! are useful independent designs for this question.
4. **Public solved cases.** Held-out diagnoses measure causal recovery and
   reviewer burden on real cases. Knowledge dates and any prior use in model
   calibration must be recorded.
5. **Controlled clinical evaluation.** Previously unsolved cases remain inside
   the approved clinical environment. Qualified reviewers adjudicate returned
   candidates. Only this stage can estimate incremental diagnostic yield.

For every stage, report input cases, known-causal cases, completed cases,
candidate rows, target type, thread count, wall time, peak RSS, engine version,
source revision, profile, and knowledge cutoff.

### ClinVar change has two independent axes

RClinVarbitration retains disease-level SCV evidence and computes named policy
profiles with explicit submitter exclusions. This supports two different
comparisons:

1. hold the policy receipt fixed and compare two ClinVar releases;
2. hold the release fixed and compare two submitter-exclusion policies.

Do not change release and policy together. That would make it impossible to
tell whether a decision changed because ClinVar evolved or because evidence
from a submitter was admitted or excluded. `bench_classification_diff()`
enforces this rule and keeps the disease key, allele, original classifications,
stars, policy receipts, and transition type.

RClinVarbitration owns the ClinVar entity keys and exports a source-rich
disease-decision Parquet with stable record keys, complete-row content
receipts, and nested SCV and RCV receipts. DuckLake owns publication snapshots
and the data-change feed. Register the Parquet, merge only changed record keys
into the persistent table, and obtain exact insert, delete, and update images
with `get_table_changes()`. VariantStoryBench summarizes those declared
changes; it does not maintain a second ClinVar parser, snapshot engine, or
identity scheme.

An allele-level summary may be derived later, but it must not replace the
disease-level transition relation: one allele can have different evidence and
decisions for different conditions.

## Comparator profiles

Talos is an established-disease-gene reanalysis comparator. Its supported
variant modules, pedigree behavior, PanelApp/phenotype filtering, and
candidate-output contract should be reproduced at a pinned commit. A separate
VariantStory profile may test candidate genes outside established panels. That
is an extension benchmark, not a Talos disagreement.

Gene-discovery evaluation requires a historical knowledge cutoff. A causal
gene counted as a discovery target must not have been available to the engine
through its gene-disease, panel, literature, or training resources at that
cutoff. Report established-gene and discovery strata separately.

The annotation-throughput benchmark is also separate from case ranking.
DuckHTS/DuckVEP, `variant_myth`, Ensembl VEP, and other annotators may be
compared on the same variants and requested fields, but annotation speed does
not establish diagnostic performance.

## Public and private assets

The public repository contains benchmark code and redistributable fixtures.
External engines are executed through adapters and retain their own licences.
Private VariantStory code, clinical records, exact private answer keys,
restricted predictor tables, and licensed OMIM data are not copied here.

The following projects are reference seeds, not vendored dependencies:

| Project | Inspected revision | Treatment |
|:--|:--|:--|
| Talos | `dc0278df0c0af80614963444f3766e22e8124c27` | MIT comparator; pin executable and resource releases |
| variant_myth | `8261529d6a1e452d6bb3b33bfd0326e98f63d147` | MIT annotation comparator |
| ReVUS | `7a082199d108d5eb3fe56f57ec846fb7a9c50ae9` | MIT code and ClinVar-derived temporal labels under the repository's stated data terms |
| sugi-variant | `9d6ffb8ff588ab9f46313f29d70255188deed40f` | design reference only; no repository licence was present at inspection |

Do not copy code or data from a seed whose licence or redistribution terms are
absent or incompatible. Predictor outputs such as REVEL, AlphaMissense, CADD,
SpliceAI, and licensed OMIM data remain local resources under their own terms.

## The July 30 milestone

The credible public milestone is an executable protocol plus measured fixture
and public-spike-in results. It may describe the planned controlled clinical
evaluation and blinded company-derived spike-ins. It must not claim clinical
validation, Middle Eastern cohort performance, or incremental diagnostic yield
before those studies and approvals exist.
