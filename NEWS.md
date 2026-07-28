# VariantStoryBench 0.1.0.9000

- Made clinical allele orientation explicit. `causal_allele_truth` now records
  whether each variant causal answer targets the source REF allele or one exact
  ALT ordinal; generic causal IDs include that role. A singleton intentionally
  uses causal REF, while a phenotyped confirmed-negative case carries an ALT,
  proving that `called_alternate` is transport state, not pathogenicity.

- Split coarse sequence truth into exact `allele_truth` and `genotype_truth`.
  The former preserves source and expected canonical GRCh38 geometry by source
  record/ALT ordinal, including one deliberately suffix-minimized indel; the
  latter preserves GT, GQ, DP, ploidy, phase, and call state per person.
  `bench_allele_transport_metrics()` and `bench_genotype_transport_metrics()`
  now score engine-neutral output without exposing evaluator truth to engines.

- Added `bench_validate_frequency_observations()` as an engine-neutral typed
  case-frequency contract. It preserves provider-row multiplicity and rejects
  fabricated absence, collapsed conflicts, AC/AN/status contradictions,
  incorrect AF derivation, and shard-localization drift.

- Wrapped the unchanged canonical `ducksemantics` HPO fields with explicit
  `case_id`, `person_id`, and `observation_id` evaluator identity. Validation
  now rejects document/case mismatch and undeclared people, and extraction
  metrics include case/person grain so moving a relative's phenotype to the
  proband cannot score as an exact match.

- Removed the Bench-owned GQ quality policy and the unused inheritance, CNV,
  and reanalysis recovery metrics. GQ/DP transport is now exact truth rather
  than a Bench-owned quality threshold; inheritance and CNV truth remain sealed
  for future scientific evaluation.

- Pinned the tested GitHub revisions of the non-CRAN `ducksemantics` import and
  the `Rduckhts` monorepo subpackage so clean dependency resolution installs the
  required exported connection API, and removed unrelated development packages
  from the R-CMD-check workflow.

- Corrected symbolic-CNV BED semantics in the micro-cohort: VCF `POS=549997`
  is the one-based padding/base-before-event coordinate and `END=559997` is
  the inclusive last affected base. Excluding the padding base gives the
  affected interval `[549997, 559997)` (10,000 bp); the VCF remains unchanged,
  while CNV IDs and evaluator truth now use this interval.

- Corrected the generated micro-cohort to use Ensembl GRCh38 primary-assembly
  contigs (`1`, `2`, and `7`) and verified REF alleles at `1:100000` (`C`),
  `1:100100-100102` (`TGC`), normalized deletion `2:199999-200000` (`TG` to `T`),
  `2:200100` (`T`),
  `2:200200` (`A`), `2:200300` (`T`), and normalized symbolic deletion
  `7:549997` (`T` for `<DEL>`, `END=559997`). Causal/record IDs and CNV truth
  now use those coordinates.
  These micro-coordinates were checked against Ensembl release 116 GRCh38
  primary assembly; no reference FASTA is bundled. Generated headers now use
  the specification-valid `##fileformat=VCFv4.2` declaration.

- Aligned sealed engine admission with VariantStory: added person-grain VCF
  sample mappings, exact admitted relationship columns, one source document
  per case (including empty CNV phenotype plans), and person-grain genotype
  calls.
- Expanded trio sequence fixtures to every sample/record and retained raw GQ/DP
  fields for exact transport checks without defining a quality threshold.

- Sealed generated engine inputs from evaluator truth: removed generated oracle
  results and generic command adapters, and now return separate engine-input
  and evaluator-truth bundles. The text provider receives phenotype/context
  and family presentation only.
- Replaced the local HPO shape with the canonical `ducksemantics` source
  document and observation contract, including exact text/bounds validation
  and `absent/negated` context.
- Promoted the symbolic deletion to a typed `cnv` case with GRCh38/BED
  coordinates and XCNV authority; CNV metrics now score
  assembly/type/interval separately from authority.
- Removed generic temporal anti-join-count validation and metrics. Temporal
  source selection remains explicitly unsupported until executable source
  relations exist.
- Added sealed-bundle leakage, all-VCF Rduckhts round-trip, canonical HPO,
  empty-denominator, and typed-CNV regression coverage.

- Added `ARCHITECTURE.md` and an executable relation/metric benchmark
  contract for synthetic generation, declared result relations, and evaluation.
- Removed the lossy compact result reader, validator, metric, test, and
  fixture. Comparative evaluation now uses the relational contract only.
- Added a `vcfppR`-written GRCh38 micro-cohort with singleton and trio VCFs,
  causal SNV/indel truth, benign distractors, raw parental GQ/DP fields,
  no-call contrasts, a symbolic XCNV fixture, latent HPO/pedigree truth,
  provider-realised notes, and explicit unsupported capability rows.
- Required candidate ranks to be unique and contiguous per emitted case unit
  and required present source spans to be strictly nonempty zero-based,
  half-open intervals.
- Added HPO term/context/span extraction metrics and retained sealed
  sequence, inheritance, and CNV truth relations for future evaluation.
- Changed the `targets` pipeline to generate and validate the micro-cohort
  rather than read a compact fictional result CSV.

- Replaced the initial documentation scaffold with an executable R package.
- Added validated result manifests, ranking metrics, and a `targets` pipeline.
- Added a comparative manifest contract for cases, causal answers, exact run
  receipts, per-case execution coverage, and ranked candidates.
- Added coverage-aware top-k recall, mean reciprocal rank, and candidate-burden
  metrics that keep failed and unsupported cases visible and distinguish
  unresolved cases from confirmed negative controls.
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
