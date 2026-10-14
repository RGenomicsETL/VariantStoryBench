# VariantStoryBench architecture

VariantStoryBench owns public scoped benchmark selection, result contracts, scoring and reports.
It composes the same providers as VariantStory; it does not implement clinical policy or storage.

## Specification sequence

[Whole-system abstract specification][system] -> functional refinement ->
[implementation-motivated refinement and specification][implementation].

The [public-data plan](public-data-plan.md) applies that design to this package.
The [temporal specification](temporal-benchmark.md) defines ReVUS-style public experiments.

```text
public dated provider relations + scope/dates
      -> benchmark input rows and public outcome rows
      -> VariantStory adapter -> declared results
      -> scoring -> per-unit comparisons and aggregate metrics
```

Public labels do not become prediction features. No private evaluation system is required.
Build SCV, RCV and VCV experiments from existing DuckClinVarbitration history.
Compose ducksemantics and DuckVEP/vep-rs where those inputs are needed.
Compare incremental results with a full run on identical facts and method settings.

## Current code and planned additions

The package has result validators and metrics in `R/`, with tests in `inst/tinytest/`.
It also contains generated micro-cohort developer fixtures. Those are software tests,
not the public study population or prerequisites for study delivery.
No new runtime behavior is implemented by these specification changes.

Add scoped public source views, a VariantStory adapter, temporal outcome selection,
and paired full/incremental comparisons. Reuse the current result validators where compatible.
Public inputs do not have to come from `bench_generate_micro_cohort()`.
The existing fixture generator, transport tests and result APIs remain unchanged.

Keep source/release/date, scope and method settings in small ordinary tables/configuration.
Reuse metadata from providers. Do not add another importer, checksum service or approval workflow.
Use R and SQL, not a new generic execution framework.

See [benchmark-contract.md](benchmark-contract.md) for current result interfaces.
Scientific forecast, reanalysis, policy comparison and case ranking are separately named tasks.
Observed public reclassification is not an independent clinical diagnosis.

[system]: https://github.com/RGenomicsETL/VariantStory/blob/docs/bioconnect-reanalysis-plan/design/system-specification.md
[implementation]: https://github.com/RGenomicsETL/VariantStory/blob/docs/bioconnect-reanalysis-plan/design/implementation-specification.md
