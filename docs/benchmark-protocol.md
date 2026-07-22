# Benchmark protocol

## Stages

1. **Executable fixtures:** evidence bounds, caps, missing/conflicting values,
   inheritance, phase, SNV/indel/MNV, CNV/SV and no-causal cases.
2. **Synthetic spike-ins:** seeded causal variants with clean, sparse, noisy
   and misleading HPO profiles, plus inheritance and ancestry strata.
3. **Temporal reanalysis:** freeze an earlier evidence snapshot, add later
   evidence, and verify that changes are traceable without rewriting history.
4. **Public solved cases:** measure causal-variant recall, top-k ranking and
   candidate burden on permitted public or controlled-access manifests.
5. **Clinical evaluation:** a separately governed cohort with qualified review;
   this stage is outside this repository's data and licence boundary.

## Leakage controls

- Keep case generation independent of the scoring implementation.
- Hold out seeds, genes, diseases, variant classes and ancestry groups.
- Pin input releases, tool versions, configuration and random seeds.
- Record every adapter invocation and result receipt.

## Metrics

- top-1/top-3/top-5/top-10 causal recall;
- candidates per case and no-causal candidate burden;
- mean reciprocal rank;
- inheritance, phase and variant-class strata;
- phenotype-noise sensitivity;
- runtime, memory and reproducibility.

Candidate ranking is not a clinical diagnosis. Incremental diagnostic yield
requires confirmed outcomes and qualified clinical review.
