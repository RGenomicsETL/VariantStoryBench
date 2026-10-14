stopifnot(requireNamespace("duckdb", quietly = TRUE))
source("R/11-public-temporal.R")
for (file in list.files("inst/tinytest", pattern = "^test-public-.*\\.R$", full.names = TRUE)) {
  result <- tinytest::run_test_file(file)
  stopifnot(all(as.data.frame(result)$result %in% TRUE))
}
