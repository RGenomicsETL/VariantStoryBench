bench_required_columns <- function(x, required) {
  missing <- setdiff(required, names(x))
  if (length(missing)) {
    stop(
      "results are missing required columns: ",
      paste(missing, collapse = ", "),
      call. = FALSE
    )
  }
}

#' Validate benchmark result rows
#'
#' @param results A data frame with `case_id`, `cohort`, `causal_rank`, and
#'   `candidate_count` columns. This legacy compact format cannot distinguish
#'   an unresolved case, a confirmed negative, a failed evaluation, or a known
#'   causal answer that was not recovered. Use the relational manifests and
#'   [bench_rank_metrics()] for comparative work.
#' @return `results`, invisibly.
#' @export
bench_validate_results <- function(results) {
  if (!is.data.frame(results)) {
    stop("results must be a data frame", call. = FALSE)
  }
  bench_required_columns(results, c("case_id", "cohort", "causal_rank", "candidate_count"))
  if (!is.character(results$case_id) || anyNA(results$case_id) || any(!nzchar(results$case_id))) {
    stop("results$case_id must contain non-empty strings", call. = FALSE)
  }
  if (anyDuplicated(results$case_id)) {
    stop("results$case_id must be unique", call. = FALSE)
  }
  if (!is.character(results$cohort) || anyNA(results$cohort) || any(!nzchar(results$cohort))) {
    stop("results$cohort must contain non-empty strings", call. = FALSE)
  }
  if (!is.numeric(results$causal_rank) ||
      any(!is.na(results$causal_rank) &
          (results$causal_rank < 1 | results$causal_rank != floor(results$causal_rank)))) {
    stop("results$causal_rank must contain positive integers or NA", call. = FALSE)
  }
  if (!is.numeric(results$candidate_count) ||
      any(is.na(results$candidate_count) | results$candidate_count < 0 |
          results$candidate_count != floor(results$candidate_count))) {
    stop("results$candidate_count must contain non-negative integers", call. = FALSE)
  }
  invisible(results)
}

#' Read benchmark results
#'
#' @param path CSV path containing benchmark result rows.
#' @return A validated data frame.
#' @export
bench_read_results <- function(path) {
  path <- bench_path(path, "path", must_exist = TRUE)
  results <- utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
  bench_validate_results(results)
  results
}

#' List benchmark result manifests
#'
#' @param path Directory containing CSV result manifests.
#' @return Sorted CSV paths.
#' @export
bench_manifest_paths <- function(path = system.file("extdata", package = "VariantStoryBench")) {
  if (!is.character(path) || length(path) != 1L || is.na(path) || !dir.exists(path)) {
    stop("path must be an existing directory", call. = FALSE)
  }
  paths <- sort(list.files(path, pattern = "[.]csv$", full.names = TRUE))
  if (!length(paths)) stop("no CSV manifests found in: ", path, call. = FALSE)
  paths
}
