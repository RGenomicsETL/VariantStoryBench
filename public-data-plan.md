# Public-data evaluation plan

VariantStoryBench selects public records and evaluates VariantStory and VariantLake.
The companion projects are intended for public GPL-2.0-or-later resets.
This PR changes specifications, not repository history or visibility.

Read the [abstract system][system], then its [implementation refinement][implementation].
Use [temporal-benchmark.md](temporal-benchmark.md) for this package's dated experiments.

## Components to compose

| Component | Reuse |
|---|---|
| DuckClinVarbitration / RClinVarbitration | Public XML releases, submission/condition/variant history, arbitration and transition queries |
| ducksemantics | Dated disease/ontology facts and source-grounded retrieval |
| DuckHTS | Public callset reading, identity and genotype mechanics |
| DuckVEP or vep-rs | Incremental consequence annotation under a recorded model/version |
| VariantLake | Mainstream storage and semantic change relations |
| VariantStory | Evidence assessment, numerical classification, ranking and reanalysis |

This package selects scopes/dates, calls the analysis adapter, and scores outputs.
Do not add another source importer, policy engine or generic workflow framework.

## First public experiments

Start with ReVUS-style VUS transitions from dated ClinVar releases.
Extend them at SCV, RCV and VCV grain without conflating disease-specific and aggregate labels.
Compare full and incremental annotation/analysis on the same public inputs.
Add public-case ranking where public genotypes and phenotypes support it.
Public callsets without diagnoses support transport/scale tests, not diagnostic recovery.

Benchmark generation is a scoped query over public data. No invented cases,
spike-ins, generated narratives or private cohorts form the study population.
Existing synthetic edge fixtures remain normal developer tests only.

## Configuration and outputs

Keep provider/release/source URL, dates, scope, method/options and policy version.
Keep public labels out of prediction inputs, but publish both along with selection/scoring code.
No separate evaluator service, mandatory checksum chain or approval stage is required.
Respect source redistribution terms; link large or nonredistributable source artifacts.

Produce per-unit outcomes/predictions, transitions, coverage, metrics and resource measurements.
Preserve unresolved/conflicting/removed outcomes and disclose source-label overlap.
Current validators and metrics are reusable; new public adapters and temporal execution remain implementation work.

[system]: https://github.com/RGenomicsETL/VariantStory/blob/docs/bioconnect-reanalysis-plan/design/system-specification.md
[implementation]: https://github.com/RGenomicsETL/VariantStory/blob/docs/bioconnect-reanalysis-plan/design/implementation-specification.md
