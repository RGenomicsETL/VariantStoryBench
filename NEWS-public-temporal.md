# Public temporal implementation

- Add `bench_public_transitions()` for dated public snapshot comparisons at unit,
  condition, and submitter grain. Keep prediction inputs separate from public outcomes.
- Add `bench_compare_relations()` for full multiset comparisons, including duplicate rows and NULL values.
- Add focused tests for dates, condition identity, rollback, and result differences.
- Add the shared technical-explanations skill and a Quarto/Mermaid implementation guide.

Existing developer fixtures and their historical changelog remain unchanged.
