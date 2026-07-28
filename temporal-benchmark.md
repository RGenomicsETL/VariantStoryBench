# Temporal benchmark release decision

**Status:** selected design; provider capture and executable case selection remain incomplete.

## Two tracks

### ClinVar transition

Follow the useful ReVUS design: select earlier-release VUS and label their later observed state as transition toward pathogenic, transition toward benign, conflict, retirement, or persistent VUS.

VariantStoryBench additionally retains exact allele and ClinVar merge lineage, evaluates disease-level RCV/SCV facts under one fixed RClinVarbitration policy, and admits only earlier-epoch predictors and provider artifacts. ReVUS's shipped predictor features came from a 2026 BioBTree snapshot; they can reproduce that study but are not admissible as 2022 inputs in this strict track.

### Case reanalysis

This is the primary VariantStory task. It asks whether an admitted case changes after new human curation, literature, disease knowledge, or an expert specification becomes available. It measures newly recoverable solutions, exact evidence deltas, classification and rank changes, review burden, and correct abstention.

## Selected epochs

| Epoch | Availability cutoff | Role |
|---|---|---|
| `E0_2024_01_23` | `2024-01-23T23:59:59Z` | engine input and baseline result |
| `E1_2026_07_21` | `2026-07-21T23:59:59Z` | evaluator outcome and reanalysis result |

These are public-availability cutoffs, not only dates printed inside records. A source enters an epoch only if its exact released object was publicly available by the cutoff.

| Provider | E0 | E1 | Use |
|---|---|---|---|
| ClinVar GRCh38 | `clinvar_20240107.vcf.gz` | `clinvar_20260706.vcf.gz` | assertions, first-seen curation, transitions |
| Monarch KG | tag `2024-01-13`, published 2024-01-23 | tag `2026-07-14`, published 2026-07-17 | disease-mediated retrieval and phenotype associations |
| ClinGen CSpec | exact versions released by E0 | exact versions released by E1 | criterion applicability and strength |
| ClinGen gene-disease | latest exact artifact available by E0 | latest exact artifact available by E1 | gene-condition validity and mechanism |
| PubMed | 2024 baseline plus updates available by E0 | 2026 baseline plus updates available by E1 | literature first-seen evidence |
| HPO | latest exact release available by E0 | latest exact release available by E1 | phenotype identity and ontology calculations |

ClinGen gene-disease, PubMed, HPO, and historical CSpec rows remain `pending_receipt` until exact artifacts and digests are audited. Current data must never be relabelled as an old snapshot. If a historical artifact cannot be obtained, that provider is `unavailable` for E0.

BRCA1 CSpec `GN092/version/1.2.1` has a released event on 2025-01-09, so it is E1-only and supplies a real specification delta.

## Provider time rules

Every epoch needs one row per provider with exact release ID, source URL, release and first verified availability times, payload and receipt digests, selected policy receipt, and status.

- **ClinVar:** first availability is the first retained release containing the SCV/RCV fact under the fixed policy. `DateLastEvaluated` alone does not prove availability.
- **CSpec:** require the exact version IRI, released-event time, and retained source bytes. A current response claiming an old version is not a historical artifact unless receipt-matched.
- **PubMed:** both baseline/update-file availability and Entrez history must satisfy the cutoff. Publication year alone is insufficient.
- **Monarch:** an edge first exists in the first exact Monarch release containing it. Upstream dates remain provenance; they cannot move an edge into an unavailable release.
- **ClinGen gene-disease:** require an exact archival artifact and publication time. Per-record approval dates do not replace its receipt.

ClinVar, ClinGen, and PubMed may establish a new human-curation label. Monarch is an aggregated retrieval resource and does not establish that label by itself.

## Leakage rule

The engine receives only E0 case facts and E0 provider rows. E1 assertions, articles, specifications, ontology edges, causal and solution identifiers, first-seen labels, generation plans, and scoring oracles remain evaluator-only.

Each evidence item records the first retained provider release containing it. It cannot enter E0 when first available after E0, even if an internal evaluation, submission, or publication date is older.

## Naturally changing cohorts

Initial strata are:

1. E0 VUS or absent assertion followed by a disease-matched E1 pathogenic or likely pathogenic ClinVar assertion under the fixed policy;
2. an E1 ClinGen gene-disease or CSpec release that changes an executable interpretation path;
3. a PubMed claim first available in E1 and admitted by RClinVarbitration's typed literature projection;
4. an E1 pathogenic missense assertion that can support PM5 for a different candidate missense allele;
5. negative controls whose source state changes but whose case result should not change.

Report source type, gene, disease, variant type, E0 and E1 review status, submitter stratum, and whether E1 resolved an allele or only added evidence. Report gene-disjoint and disease-disjoint subsets with the full temporal set.

## PM5 truth

PM5 is a relation between exact alleles, never a codon-number inference. A positive row requires:

- candidate and evidence alleles annotated by the same receipt-bound DuckVEP transcript model;
- missense consequences on the same transcript;
- the same reference amino acid and protein position but different alternate amino acids;
- a disease- and mechanism-matched E1 pathogenic assertion for the evidence allele;
- exact assertion identity, provider release, and first availability after E0;
- strength admitted by the selected CSpec profile.

The same amino-acid substitution belongs to PS1 and is excluded. Position-only matches, different transcripts, unmatched diseases, and post-cutoff assertions are negative tests. Missing E0 assertions remain explicit states, not benign evidence.

## LLM-authored documents

An LLM may realize a sealed structured presentation as clinical prose. It receives only age, sex, phenotypes, explicit negations, person-attributed family facts, and permitted distractors—not the causal allele, gene, disease, later evidence, ranking, or expected classification.

The frozen receipt binds model, runtime, prompt digest, allowed-fact digest, output digest, and validation result. Deterministic validation rejects unsupported phenotypes, person misattribution, leaked gene/variant/disease identifiers, and altered negation. Authoring and engine-under-test models are separately configured.

This controlled-realization lane can contribute to headline metrics. A model asked to invent a case from disease knowledge cannot, because its pretrained knowledge date is not auditable. Engine LLM claims are accepted only when entailed by the case document or a supplied E0 source excerpt.

## Completion evidence

The release requires receipt-checked epoch manifests, an R/DuckDB cohort builder, exact allele and assertion lineage, PM5 truth and negative controls, frozen documents and authoring receipts, an E0-only engine bundle, inaccessible evaluator truth, and independent temporal, classification, ranking, evidence-delta, and review-burden metrics.

Until these exist, call the dates a selected release design, not a completed benchmark release.
