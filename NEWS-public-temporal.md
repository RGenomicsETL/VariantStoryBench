# Public temporal implementation

- Add `bench_transition_metrics()` with explicit task denominators, abstention coverage, tie-aware average precision, ROC AUC, and classification metrics.
- Separate resolved direction from observed pathogenic resolution. Do not treat unresolved variants as biologically benign.
- Test ties, missing predictions, empty and single-class subsets, probability values, and task-specific exclusions.
- Select the latest eligible complete unit revision from retained histories at each cutoff.
- Compare UTC epoch values without loading ICU to parse cutoff strings.
- Preserve changed condition/submitter contexts as `context_changed` and `later_contexts`, not unexplained absence.
- Test history selection, future-row exclusion, changed contexts, and operation with extension loading disabled.
- Add `bench_public_transitions()` for dated public comparisons at unit, condition, and submitter grain.
- Keep prediction inputs separate from public outcomes.
- Add `bench_compare_relations()` for full multiset comparisons, including duplicate rows and NULL values.
- Add focused tests for dates, condition identity, rollback, and result differences.
- Add the shared technical-explanations skill and Quarto/Mermaid implementation guides.

Existing developer fixtures and their historical changelog remain unchanged.
