stopifnot(requireNamespace("duckdb", quietly = TRUE))
source("R/11-public-temporal.R")
result <- tinytest::run_test_file("inst/tinytest/test-public-temporal.R")
stopifnot(all(as.data.frame(result)$result %in% TRUE))
