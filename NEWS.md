# VariantStoryBench 0.1.0.9000

- Replaced the initial documentation scaffold with an executable R package.
- Added validated result manifests, ranking metrics, S7 command adapters,
  `s7contract` conformance checks, `blit` execution, and a `targets` pipeline.
- Added a comparative manifest contract for cases, causal answers, exact run
  receipts, per-case execution coverage, and ranked candidates.
- Added coverage-aware top-k recall, mean reciprocal rank, and candidate-burden
  metrics that keep failed and unsupported cases visible and distinguish
  unresolved cases from confirmed negative controls.
- Clarified that the original compact result format cannot distinguish an
  unresolved case from a missed causal answer and is not suitable for
  comparative recall claims.
- Added an executable multi-engine fixture and a public benchmark protocol for
  spike-ins, temporal holdouts, public solved cases, gene discovery, and later
  controlled clinical evaluation.
- Added disease-level classification transition and submitter-policy
  sensitivity comparisons. The API rejects comparisons that change the ClinVar
  release and submitter policy at the same time.
- Declared RClinVarbitration's source-rich disease-decision Parquet as the
  authority for ClinVar entity identity and SCV/RCV receipts, DuckLake as the
  snapshot and data-change-feed layer, and VariantStoryBench as the
  engine-neutral measurement layer.
- Added source-grounded judgment manifests for phenotype, inheritance,
  mechanism, disease, literature, and gene-discovery claims. Every judgment
  must cite an exact versioned source record and field, plus a text span where
  applicable; unsupported model prose is rejected.
- Added grounding audit metrics without presenting citation presence as
  scientific correctness.
- Released the package under GPL-3.
