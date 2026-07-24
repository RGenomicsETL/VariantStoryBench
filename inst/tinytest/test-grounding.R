library(tinytest)

fixture <- function(name, kind) {
  bench_read_manifest(
    system.file("extdata", name, package = "VariantStoryBench"),
    kind
  )
}

judgments <- fixture("benchmark-judgments.csv", "judgments")
sources <- fixture(
  "benchmark-judgment-sources.csv", "judgment_sources"
)
candidates <- fixture("benchmark-candidates.csv", "candidates")

metrics <- bench_grounding_metrics(judgments, sources, candidates)
expect_equal(metrics$grounded_candidate_count, 1L)
expect_equal(metrics$judgment_count, 2L)
expect_equal(metrics$supports_count, 1L)
expect_equal(metrics$insufficient_evidence_count, 1L)
expect_equal(metrics$mean_sources_per_judgment, 1.5)
expect_equal(metrics$unique_source_record_count, 3L)

missing_source <- sources[sources$claim_id != "mechanism-fit", ]
expect_error(
  bench_validate_grounding(judgments, missing_source, candidates),
  "every judgment must cite"
)

wrong_stance <- sources
wrong_stance$stance[wrong_stance$claim_id == "phenotype-fit"] <- "context"
expect_error(
  bench_validate_grounding(judgments, wrong_stance, candidates),
  "matching stance"
)

bad_span <- sources
bad_span$span_end[[1L]] <- bad_span$span_start[[1L]] - 1L
expect_error(
  bench_validate_judgment_sources(bad_span),
  "zero-based integer intervals"
)

unknown_candidate <- judgments
unknown_candidate$candidate_id <- "GENE_UNKNOWN"
unknown_candidate_sources <- sources
unknown_candidate_sources$candidate_id <- "GENE_UNKNOWN"
expect_error(
  bench_validate_grounding(
    unknown_candidate, unknown_candidate_sources, candidates
  ),
  "emitted candidate"
)
