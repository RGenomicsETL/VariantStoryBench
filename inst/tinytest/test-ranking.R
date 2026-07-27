library(tinytest)

fixture <- function(name, kind) {
  bench_read_manifest(
    system.file("extdata", name, package = "VariantStoryBench"),
    kind
  )
}

cases <- fixture("benchmark-cases.csv", "cases")
truth <- fixture("benchmark-truth.csv", "truth")
runs <- fixture("benchmark-runs.csv", "runs")
evaluations <- fixture("benchmark-evaluations.csv", "evaluations")
candidates <- fixture("benchmark-candidates.csv", "candidates")

metrics <- bench_rank_metrics(
  cases, truth, runs, evaluations, candidates,
  top_k = c(1L, 3L), by = "target_type"
)

expect_equal(nrow(metrics), 6L)
fixture_a_variant <- metrics[
  metrics$run_id == "fixture-a-2026" & metrics$target_type == "variant",
]
expect_equal(fixture_a_variant$case_count, 4L)
expect_equal(fixture_a_variant$known_causal_case_count, 2L)
expect_equal(fixture_a_variant$top_1_recall, 0.5)
expect_equal(fixture_a_variant$top_3_recall, 1)
expect_equal(fixture_a_variant$unresolved_candidate_burden, 1)
expect_equal(fixture_a_variant$confirmed_negative_candidate_burden, 0)

fixture_b_gene <- metrics[
  metrics$run_id == "fixture-b-2026" & metrics$target_type == "gene",
]
expect_equal(fixture_b_gene$unsupported_case_count, 1L)
expect_equal(fixture_b_gene$top_1_recall, 0)

missing_coverage <- evaluations[-1L, ]
expect_error(
  bench_rank_metrics(cases, truth, runs, missing_coverage, candidates),
  "every run and case unit"
)

bad_truth <- rbind(
  truth,
  data.frame(
    case_id = "fixture-unsolved",
    target_type = "variant",
    causal_id = "3:700:C:T"
  )
)
expect_error(
  bench_rank_metrics(cases, bad_truth, runs, evaluations, candidates),
  "known_causal"
)

bad_candidates <- rbind(
  candidates,
  data.frame(
    run_id = "fixture-b-2026",
    case_id = "fixture-splice",
    target_type = "variant",
    candidate_id = "2:400:AT:A",
    rank = 1L
  )
)
expect_error(
  bench_rank_metrics(cases, truth, runs, evaluations, bad_candidates),
  "completed evaluation"
)

duplicate_rank <- candidates
idx <- duplicate_rank$case_id == "fixture-splice" &
  duplicate_rank$run_id == "fixture-a-2026"
duplicate_rank$rank[idx] <- 1L
expect_error(bench_validate_candidates(duplicate_rank), "unique and contiguous")

gapped_rank <- candidates
idx <- gapped_rank$case_id == "fixture-splice" &
  gapped_rank$run_id == "fixture-a-2026" & gapped_rank$rank == 3L
gapped_rank$rank[idx] <- 4L
expect_error(bench_validate_candidates(gapped_rank), "unique and contiguous")

reanalysis <- bench_reanalysis_metrics(
  cases, truth, runs, evaluations, candidates,
  baseline_run_id = "fixture-b-2026",
  reanalysis_run_id = "fixture-a-2026",
  top_k = 1L
)
reanalysis_variant <- reanalysis[reanalysis$target_type == "variant", ]
expect_equal(reanalysis_variant$known_causal_case_count, 2L)
expect_equal(reanalysis_variant$baseline_unsupported_case_count, 0L)
expect_equal(reanalysis_variant$top_k_recall_delta, 0.5)
expect_equal(reanalysis_variant$recovered_gain_count, 1L)
expect_equal(reanalysis_variant$rank_improved_count, 1L)
