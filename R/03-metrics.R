#' Calculate ranking metrics
#'
#' @param results Validated benchmark result rows.
#' @param top_k Positive integer ranking cutoffs.
#' @return One-row data frame of aggregate metrics.
#' @export
bench_metrics <- function(results, top_k = c(1L, 3L, 5L, 10L)) {
  bench_validate_results(results)
  if (!is.numeric(top_k) || !length(top_k) || anyNA(top_k) ||
      any(top_k < 1L | top_k != floor(top_k))) {
    stop("top_k must contain positive integers", call. = FALSE)
  }
  top_k <- sort(unique(as.integer(top_k)))
  ranked <- results[!is.na(results$causal_rank), , drop = FALSE]
  no_causal <- results[is.na(results$causal_rank), , drop = FALSE]

  out <- list(
    case_count = nrow(results),
    solved_case_count = nrow(ranked),
    no_causal_case_count = nrow(no_causal),
    mean_reciprocal_rank = if (nrow(ranked)) mean(1 / ranked$causal_rank) else NA_real_,
    mean_candidate_burden = mean(results$candidate_count),
    no_causal_candidate_burden = if (nrow(no_causal)) {
      mean(no_causal$candidate_count)
    } else {
      NA_real_
    }
  )
  for (k in top_k) {
    out[[paste0("top_", k, "_recall")]] <- if (nrow(ranked)) {
      mean(ranked$causal_rank <= k)
    } else {
      NA_real_
    }
  }
  as.data.frame(out, check.names = FALSE)
}
