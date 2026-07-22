library(tinytest)

path <- system.file("extdata", "synthetic-results.csv", package = "VariantStoryBench")
results <- bench_read_results(path)
metrics <- bench_metrics(results)

expect_equal(nrow(results), 4L)
expect_equal(metrics$case_count, 4L)
expect_equal(metrics$solved_case_count, 3L)
expect_equal(metrics$no_causal_case_count, 1L)
expect_equal(metrics$top_1_recall, 1 / 3)
expect_equal(metrics$top_3_recall, 2 / 3)
expect_equal(metrics$top_10_recall, 1)
expect_equal(metrics$no_causal_candidate_burden, 0)

bad <- results
bad$case_id[[2L]] <- bad$case_id[[1L]]
expect_error(bench_validate_results(bad), "unique")
