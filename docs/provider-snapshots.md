# Use complete public provider releases


## Select a release before selecting outcomes

`bench_public_release_snapshot()` selects one complete release at an
inclusive cutoff. It retains all source columns and types. It does not
retrieve absent units from older releases.

``` mermaid
flowchart LR
  M[Complete release dates] --> C[Choose latest available release]
  H[All imported source rows] --> S[Select only that release]
  C --> S
  S --> T[Typed snapshot, including an empty snapshot]
```

A complete release can contain no rows in the selected domain. That is
not permission to use an older release. The release-date relation has
`release_id` and `available_at`. It contains one provider’s complete
releases. Use public availability, not local import time or an
assertion’s evaluation date.

## Compose ClinVarbitration with the benchmark

`bench_clinvar_arbitration_snapshot()` reads existing RClinVarbitration
disease decisions and policy profiles. It does not import XML, repeat
arbitration, or replace the provider’s decisions.

``` mermaid
flowchart TD
  P[RClinVarbitration disease decisions] --> A[Select one release and policy profile]
  D[Public release dates and cutoff] --> A
  A --> S[Benchmark keys and states plus all source columns]
  S --> B[Baseline snapshot]
  S --> L[Later snapshot]
  B --> T[bench_public_transitions]
  L --> T
  T --> I[Baseline features]
  T --> O[Separate observed outcomes]
```

| Source field | Benchmark field |
|----|----|
| VCV accession and allele ID | A length-prefixed `unit_id`; both original fields remain |
| Disease key | `condition_id` |
| Arbitration across submissions | NULL `submitter_id`; `grain = arbitration` |
| Existing policy classification | `state`; the original classification remains |
| Chosen release’s public date | `available_at` |

This is a derived arbitration task, not an SCV, RCV, or VCV aggregate
task. The adapter maps `VUS`, `Pathogenic/Likely Pathogenic`, `Benign`,
and `Conflicting` to benchmark states. Other source values map to
`other`; their original values remain visible.

RClinVarbitration’s `clinvar_releases` records `imported_at`. It does
not establish public availability. Supply the small
`public_release_dates` relation from the source release dates. Use the
same policy and profile at both cutoffs for a source-change experiment.

## Run the composed operations

This example needs imported provider relations and public release dates.
Rendering does not execute it.

``` r
bench_clinvar_arbitration_snapshot(
  con, releases = "public_release_dates",
  cutoff = as.POSIXct("2022-06-30", tz = "UTC"), output = "clinvar_t0",
  policy_version = "cpg-clinvarbitration-2.2.11"
)
bench_clinvar_arbitration_snapshot(
  con, releases = "public_release_dates",
  cutoff = as.POSIXct("2026-07-31", tz = "UTC"), output = "clinvar_t1",
  policy_version = "cpg-clinvarbitration-2.2.11"
)
bench_public_transitions(
  con, "clinvar_t0", "clinvar_t1",
  as.POSIXct("2022-06-30", tz = "UTC"), as.POSIXct("2026-07-31", tz = "UTC"),
  "vus_inputs", "vus_outcomes"
)
```

Extra feature columns must also be historically available. An old
release label cannot make a current feature join historical. Keep
annotation model changes separate from source-release changes.

## Tests and source contracts

Software tests cover release removal, empty releases, inclusive cutoffs,
ambiguous dates, configuration selection, and exact field preservation.
They compose the adapter with temporal selection and test independence
from later source changes. Constructed schema tests do not establish
public-cohort prediction accuracy.

The adapter follows the provider’s [disease policy
relation](https://github.com/RGenomicsETL/DuckClinVarbitration/blob/main/r/RClinVarbitration/R/policy.R).
The provider
[schema](https://github.com/RGenomicsETL/DuckClinVarbitration/blob/main/r/RClinVarbitration/R/schema.R)
defines source types and policy tables.
