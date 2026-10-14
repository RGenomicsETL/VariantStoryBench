# Dated public benchmark specification

Selected implementation contract. The public cohort builder and complete engine adapter remain work.
Follow the [whole-system specification][system] and [public-data plan](public-data-plan.md).

## Abstract experiment

Given public provider history H, scope Q, and t0 < t1:

```text
state0  = latest complete public state with available_at <= t0
state1  = latest complete public state with available_at <= t1
inputs  = state0 facts selected by Q
cohort  = eligible t0 units (for example VUS)
labels  = state1 outcomes joined to those same units
scores  = method(inputs), without t1 labels
metrics = evaluate(scores, labels)
```

All source data, selection code and labels are public. No separate evaluator service is required.
Generation means a query over dated records, not invented patients or clinical narratives.

## Three tasks

| Task | Inputs | Target |
|---|---|---|
| VUS forecast | t0 records and t0-eligible features | Later observed direction or state, following ReVUS |
| Incremental reanalysis | t0 result plus t1 public changes | Equality with a complete t1 run and correct semantic differences |
| Policy comparison | One fixed release with two named policies | Policy-induced differences, not a source update |

For [ReVUS][revus] comparability, use its declared 2022-06 and 2026-07 ClinVar releases.
Other dates are parameters, not another fixed release ceremony.
Separate predicting pathogenic resolution in all baseline VUS from predicting direction
only among later-resolved variants. The latter is conditional on a future outcome.
Report observed ClinVar transitions, not guaranteed biological truth.

## Provider composition and grain

Use DuckClinVarbitration/RClinVarbitration's imported releases and transition relations.
Reuse `rclinvarbitration_disease_release_transitions()` where its disease decision contract fits.
No second XML ingestion pipeline is needed.

| Grain | Identity | Output |
|---|---|---|
| SCV | Submission accession/version, submitter, and condition context | Submission-level state and changes |
| RCV | Accession/version with allele and condition context | Disease-specific aggregate/history |
| VCV | Variation/accession lineage | Variant aggregate/history, separately from RCV results |
| Arbitration | Exact allele plus condition and selected arbitration policy | Derived provider decision, not the original NCBI aggregate |

Preserve accession merges, replacements, withdrawn/missing records and changed conditions.
Do not merge all conditions into one label before evaluating disease-level changes.
Use the same policy at both dates when measuring source changes.

Use retained public versions or releases to reconstruct as-of state.
An old `DateLastEvaluated` on a current assertion does not prove that current content existed at t0.
Keep public availability separate from submission/evaluation dates.
A current XML file alone cannot establish every previous version.

ducksemantics supplies dated disease/ontology relations and source-grounded retrieval.
DuckVEP or vep-rs supplies consequences; cache by allele/reference, annotator, model and options.
A transcript/model change creates a new configuration and can require broad annotation refresh.

## Proposed relations and selection

Keep the provider's schemas. Build a thin view with these fields for each selected grain:

```text
provider, release, available_at, grain, unit_id, allele_id,
condition_id, submitter_id, accession_version, classification, review_status
```

Condition and submitter fields are nullable where the grain does not contain them.
The mapping must preserve the source accession rather than fabricate equivalence.

Choose one of two source contracts before selection:

- Complete release snapshots: choose the latest eligible release as a whole.
  A unit absent from that release remains absent. Do not fill it from an older release.
- Complete unit history: choose the latest eligible revision of each stable unit.
  Each revision contains all its contexts at one availability timestamp.
  A withdrawal needs an explicit retired revision. Missing historical rows do not erase older state.

Eligibility uses inclusive `available_at <= cutoff`. Compare actual availability instants,
not evaluation dates or session-dependent timezone strings. Reject ambiguous duplicate
selected unit/context rows instead of choosing an arbitrary one. Do not union all prior
versions or select old contexts independently after a complete unit revision removed them.
The unit-history adapter in PR #5 follows the second contract. A provider adapter must
select a complete release before passing release-shaped inputs to that operation.

Select baseline VUS at t0 and LEFT JOIN to t1 by the declared identity/lineage mapping.
Publish outcomes: persistent VUS, P/LP, B/LB, conflict, retired/removed, changed context, and other.
Keep t0 variables in the input relation and t1 labels in the scoring relation.
Scope by gene, disease, variant class, review level, submitter or date in SQL.

Retain unresolved, conflict and removed states. They are not biological benign labels.
For observed pathogenic resolution, retain every baseline VUS and report whether a
pathogenic outcome was observed. Keep missing/retired/context-change counts separate.
Do not infer complete follow-up from a zero event label.
Optional feature comparisons record model/training and source release dates.
A modern model applied to old evidence is a present-day retrospective method;
do not claim that model was historically available.

## Incremental experiment

```text
full(t0) + data/knowledge/scope/policy changes -> incremental(t1)
complete new inputs and method              -> full(t1)
compare normalized logical outputs and resource use
```

Declare the input unit universe and the semantic output relations before comparison.
Compare the full universe, evaluation coverage/status, source facts, assessed evidence,
classifications, candidate memberships/ranks, and findings for the selected task.
Include empty relations and duplicate multiplicity. Do not compare only relations that
happen to be nonempty in both runs; that would hide missing work and dropped units.

Exclude execution IDs, timings, physical row order, and execution-lineage pointers.
Resolve lineage pointers to their semantic source facts before comparison.
Keep source releases, policy identity, evidence contributions, and ranks in the comparison.
Retain unaffected results and apply removals, including old-only scope groups.
Incomplete dependency information requires broader recomputation.

A later pathogenic allele may affect PS1/PM5 evidence for another allele.
Match allele, transcript, amino-acid change, disease and mechanism under the selected policy.
Do not infer that relation from a codon number alone.

## Outputs and ordinary tests

Publish a small config: sources/releases, t0/t1, scope, method/options and policy version.
Reuse provider metadata; no new payload-digest or approval service is required.
Output selected rows, predictions, outcomes, transition counts and metrics.
Report AUPRC and class-aware metrics for imbalanced tasks, with denominators and coverage.
Report paired incremental/full differences, timing, memory and annotation work avoided.

Tests cover inclusive as-of filtering, complete releases and unit revisions, accession changes,
condition separation, missing later records, unchanged results, label independence,
policy-only/scope-only changes, and complete incremental/full equality.
Existing tinytest edge fixtures remain software tests, not the public study population.

[system]: https://github.com/RGenomicsETL/VariantStory/blob/docs/bioconnect-reanalysis-plan/design/system-specification.md
[revus]: https://github.com/tamerh/ReVUS
