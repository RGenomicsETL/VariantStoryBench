bench_relation_key <- function(x, columns) {
  if (!nrow(x)) return(character())
  do.call(paste, c(lapply(x[columns], as.character), sep = "\034"))
}

bench_set_counts <- function(truth, observed, columns) {
  truth_key <- unique(bench_relation_key(truth, columns))
  observed_key <- unique(bench_relation_key(observed, columns))
  true_positive <- sum(observed_key %in% truth_key)
  list(
    truth_count = length(truth_key),
    observed_count = length(observed_key),
    true_positive_count = true_positive,
    precision = if (length(observed_key)) true_positive / length(observed_key) else NA_real_,
    recall = if (length(truth_key)) true_positive / length(truth_key) else NA_real_
  )
}

bench_f1 <- function(precision, recall) {
  if (is.na(precision) || is.na(recall)) return(NA_real_)
  if (precision + recall == 0) return(0)
  2 * precision * recall / (precision + recall)
}

#' Measure HPO term, context, and span extraction
#'
#' Source documents and observations are validated through `ducksemantics`.
#' Zero denominators are reported with `NA` rates instead of silently becoming
#' perfect scores.
#'
#' @param documents Source documents for `truth`.
#' @param truth Person-grain HPO observations containing case, person, and
#'   observation identity around the canonical `ducksemantics` columns.
#' @param extracted Person-grain HPO observations emitted by a system under
#'   test.
#' @param extracted_documents Source documents for `extracted`; defaults to
#'   `documents` when extraction is over the same clinical notes.
#' @return One-row data frame of term, context, and exact-span counts and
#'   precision/recall metrics.
#' @export
bench_hpo_metrics <- function(
    documents, truth, extracted, extracted_documents = documents) {
  bench_validate_hpo_observations(documents, truth)
  bench_validate_hpo_observations(extracted_documents, extracted)
  term <- bench_set_counts(
    truth, extracted,
    c("case_id", "person_id", "document_id", "hpo_id")
  )
  context <- bench_set_counts(
    truth, extracted,
    c("case_id", "person_id", "document_id", "hpo_id", "context_status")
  )
  span <- bench_set_counts(
    truth, extracted,
    c(
      "case_id", "person_id", "document_id", "hpo_id", "start_offset",
      "end_offset", "source_text", "context_status"
    )
  )
  data.frame(
    term_truth_count = term$truth_count,
    term_extracted_count = term$observed_count,
    term_true_positive_count = term$true_positive_count,
    term_precision = term$precision,
    term_recall = term$recall,
    term_f1 = bench_f1(term$precision, term$recall),
    context_truth_count = context$truth_count,
    context_extracted_count = context$observed_count,
    context_true_positive_count = context$true_positive_count,
    context_precision = context$precision,
    context_recall = context$recall,
    context_f1 = bench_f1(context$precision, context$recall),
    span_truth_count = span$truth_count,
    span_extracted_count = span$observed_count,
    span_true_positive_count = span$true_positive_count,
    span_precision = span$precision,
    span_recall = span$recall,
    span_f1 = bench_f1(span$precision, span$recall),
    stringsAsFactors = FALSE
  )
}
