# VariantStoryBench

Shared benchmark infrastructure for rare-disease variant reanalysis.

VariantStoryBench is separate from the private VariantStory implementation. It
contains reproducible fixtures, synthetic-case generators, spike-in manifests,
metrics and adapters for declared tools. It must not contain private VariantStory
rules, clinical data, credentials or company evidence packs.

## Scope

- deterministic conformance fixtures;
- synthetic VCF/HPO/pedigree cases;
- pathogenic-variant spike-ins into permitted backgrounds;
- temporal evidence-update fixtures;
- public solved-case manifests;
- top-k recall, candidate burden and reproducibility metrics;
- adapters for VariantStory, Talos, Exomiser and other approved engines.

Synthetic and public benchmarks measure engineering and analytical performance.
They do not establish clinical diagnostic yield.

## Repository status

Early scaffold. The repository is private and currently has no public software
licence. Contributor and data terms must be agreed before external code or data
is accepted.

See [docs/benchmark-protocol.md](docs/benchmark-protocol.md).
