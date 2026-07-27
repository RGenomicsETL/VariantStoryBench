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
#' @param truth Canonical `ducksemantics` HPO observations.
#' @param extracted Canonical HPO observations emitted by a system under test.
#' @param extracted_documents Source documents for `extracted`; defaults to
#'   `documents` when extraction is over the same clinical notes.
#' @return One-row data frame of term, context, and exact-span counts and
#'   precision/recall metrics.
#' @export
bench_hpo_metrics <- function(
    documents, truth, extracted, extracted_documents = documents) {
  bench_validate_hpo_observations(documents, truth)
  bench_validate_hpo_observations(extracted_documents, extracted)
  term <- bench_set_counts(truth, extracted, c("document_id", "hpo_id"))
  context <- bench_set_counts(
    truth, extracted, c("document_id", "hpo_id", "context_status")
  )
  span <- bench_set_counts(
    truth, extracted,
    c("document_id", "hpo_id", "start_offset", "end_offset", "source_text", "context_status")
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

#' Measure strict person-grain sequence genotype recovery
#'
#' A strict recovery requires the exact case, person, record, sequence class,
#' call status, and independent quality status. `call_status` describes the
#' genotype call (`called_alternate`, `called_reference`, `partial_no_call`,
#' `no_call`, or `other_alternate`); low quality is not folded into that
#' vocabulary. Missing calls count in truth denominators, and extra calls
#' count in precision denominators.
#'
#' @param truth Declared person-grain sequence truth relation.
#' @param calls Sequence classifications, calls, and quality statuses emitted
#'   by a system.
#' @return One-row data frame of strict sequence metrics.
#' @export
bench_sequence_metrics <- function(truth, calls) {
  bench_validate_sequence_relation(truth, "truth")
  bench_validate_sequence_relation(calls, "calls")
  key <- c("case_id", "person_id", "record_id")
  joined <- merge(
    truth, calls, by = key, all.x = TRUE, sort = FALSE,
    suffixes = c("_truth", "_call")
  )
  class_match <- !is.na(joined$sequence_class_call) &
    joined$sequence_class_truth == joined$sequence_class_call
  status_match <- !is.na(joined$call_status_call) &
    joined$call_status_truth == joined$call_status_call
  quality_match <- !is.na(joined$quality_status_call) &
    joined$quality_status_truth == joined$quality_status_call
  strict_match <- class_match & status_match & quality_match
  call_key <- bench_relation_key(calls, key)
  truth_key <- bench_relation_key(truth, key)
  data.frame(
    sequence_truth_count = nrow(truth),
    sequence_call_count = nrow(calls),
    matched_record_count = sum(call_key %in% truth_key),
    sequence_class_correct_count = sum(class_match),
    call_status_correct_count = sum(status_match),
    quality_status_correct_count = sum(quality_match),
    strict_sequence_correct_count = sum(strict_match),
    sequence_class_accuracy = bench_mean_or_na(class_match),
    call_status_accuracy = bench_mean_or_na(status_match),
    quality_status_accuracy = bench_mean_or_na(quality_match),
    strict_sequence_accuracy = bench_mean_or_na(strict_match),
    strict_sequence_precision = if (nrow(calls)) sum(strict_match) / nrow(calls) else NA_real_,
    stringsAsFactors = FALSE
  )
}

#' Measure family and inheritance recovery
#'
#' @param relationships Declared latent family relationships.
#' @param inheritance_truth Declared causal inheritance relation.
#' @param recovered_relationships Relationships emitted by a system.
#' @param recovered_inheritance Inheritance calls emitted by a system.
#' @return One-row data frame of relationship and inheritance recovery metrics.
#' @export
bench_family_metrics <- function(
    relationships, inheritance_truth, recovered_relationships,
    recovered_inheritance) {
  bench_validate_relationships(relationships)
  bench_validate_inheritance(inheritance_truth, "inheritance_truth")
  bench_validate_relationships(recovered_relationships)
  bench_validate_inheritance(recovered_inheritance, "recovered_inheritance")
  family <- bench_set_counts(
    relationships, recovered_relationships,
    c("case_id", "person_id", "relative_id", "relationship")
  )
  inheritance <- bench_set_counts(
    inheritance_truth, recovered_inheritance,
    c("case_id", "causal_id", "inheritance")
  )
  data.frame(
    relationship_truth_count = family$truth_count,
    relationship_recovered_count = family$observed_count,
    relationship_true_positive_count = family$true_positive_count,
    relationship_precision = family$precision,
    relationship_recall = family$recall,
    inheritance_truth_count = inheritance$truth_count,
    inheritance_recovered_count = inheritance$observed_count,
    inheritance_true_positive_count = inheritance$true_positive_count,
    inheritance_precision = inheritance$precision,
    inheritance_recall = inheritance$recall,
    stringsAsFactors = FALSE
  )
}

#' Measure CNV recovery without collapsing CNV authority
#'
#' @param truth Declared BED-coordinate CNV truth with the authority that owns
#'   each call.
#' @param calls CNV calls emitted by a system with their declared authority.
#' @return One-row data frame with assembly/type/interval and authority metrics.
#' @export
bench_cnv_metrics <- function(truth, calls) {
  bench_validate_cnv_authority(truth, "truth")
  bench_validate_cnv_authority(calls, "calls")
  interval_columns <- c("case_id", "assembly", "contig", "cnv_type", "start", "end")
  interval <- bench_set_counts(truth, calls, interval_columns)
  strict <- bench_set_counts(truth, calls, c(interval_columns, "authority_id"))
  shared <- merge(truth, calls, by = interval_columns,
                  suffixes = c("_truth", "_call"))
  data.frame(
    cnv_truth_count = interval$truth_count,
    cnv_call_count = interval$observed_count,
    cnv_interval_true_positive_count = interval$true_positive_count,
    cnv_interval_precision = interval$precision,
    cnv_interval_recall = interval$recall,
    cnv_authority_true_positive_count = strict$true_positive_count,
    cnv_authority_precision = strict$precision,
    cnv_authority_recall = strict$recall,
    cnv_authority_mismatch_count = sum(
      shared$authority_id_truth != shared$authority_id_call
    ),
    stringsAsFactors = FALSE
  )
}

bench_run_rank_relation <- function(truth, evaluations, candidates, run_id) {
  evaluation <- evaluations[evaluations$run_id == run_id, , drop = FALSE]
  candidate <- candidates[candidates$run_id == run_id, , drop = FALSE]
  causal <- merge(candidate, truth, by = c("case_id", "target_type"))
  causal <- causal[causal$candidate_id == causal$causal_id, , drop = FALSE]
  rank <- if (nrow(causal)) {
    value <- stats::aggregate(
      causal$rank, causal[c("case_id", "target_type")], min
    )
    names(value)[[3L]] <- "causal_rank"
    value
  } else {
    data.frame(case_id = character(), target_type = character(), causal_rank = integer())
  }
  merge(evaluation, rank, by = c("case_id", "target_type"), all.x = TRUE)
}

#' Measure reanalysis deltas without dropping unavailable cases
#'
#' Baseline and reanalysis recall denominators include all known-causal case
#' units. Failed, skipped, and unsupported units are reported separately and
#' remain misses.
#'
#' @param cases,truth,runs,evaluations,candidates Declared benchmark relations.
#' @param baseline_run_id,reanalysis_run_id Run identifiers to compare.
#' @param top_k Positive recall cutoff.
#' @param by Case columns used to stratify results.
#' @return One row per requested stratum with recovery and recall deltas.
#' @export
bench_reanalysis_metrics <- function(
    cases, truth, runs, evaluations, candidates,
    baseline_run_id, reanalysis_run_id, top_k = 1L, by = "target_type") {
  bench_manifest_relations(cases, truth, runs, evaluations, candidates)
  baseline_run_id <- bench_scalar_manifest_value(baseline_run_id, "baseline_run_id")
  reanalysis_run_id <- bench_scalar_manifest_value(reanalysis_run_id, "reanalysis_run_id")
  if (identical(baseline_run_id, reanalysis_run_id)) {
    stop("baseline_run_id and reanalysis_run_id must differ", call. = FALSE)
  }
  if (!all(c(baseline_run_id, reanalysis_run_id) %in% runs$run_id)) {
    stop("both reanalysis runs must be declared", call. = FALSE)
  }
  bench_integer_values(top_k, "top_k", minimum = 1L)
  if (length(top_k) != 1L) stop("top_k must contain one cutoff", call. = FALSE)
  if (!is.character(by) || anyNA(by) ||
      any(!by %in% setdiff(names(cases), c("case_id", "truth_status")))) {
    stop("by must name case-manifest columns other than case_id and truth_status",
         call. = FALSE)
  }
  baseline <- bench_run_rank_relation(truth, evaluations, candidates, baseline_run_id)
  reanalysis <- bench_run_rank_relation(truth, evaluations, candidates, reanalysis_run_id)
  names(baseline)[names(baseline) == "status"] <- "baseline_status"
  names(baseline)[names(baseline) == "causal_rank"] <- "baseline_rank"
  names(reanalysis)[names(reanalysis) == "status"] <- "reanalysis_status"
  names(reanalysis)[names(reanalysis) == "causal_rank"] <- "reanalysis_rank"
  unit <- merge(
    cases, baseline, by = c("case_id", "target_type"), all.x = TRUE, sort = FALSE
  )
  unit <- merge(
    unit, reanalysis, by = c("case_id", "target_type"), all.x = TRUE, sort = FALSE
  )
  group_key <- do.call(paste, c(unit[by], sep = "\034"))
  pieces <- split(unit, group_key, drop = TRUE)
  out <- lapply(pieces, function(part) {
    known <- part$truth_status == "known_causal"
    baseline_rank <- part$baseline_rank[known]
    reanalysis_rank <- part$reanalysis_rank[known]
    baseline_rank[part$baseline_status[known] != "completed" | is.na(baseline_rank)] <- Inf
    reanalysis_rank[part$reanalysis_status[known] != "completed" | is.na(reanalysis_rank)] <- Inf
    data.frame(
      as.list(part[1L, by, drop = FALSE]),
      case_count = nrow(part),
      known_causal_case_count = sum(known),
      baseline_unsupported_case_count = sum(part$baseline_status == "unsupported"),
      reanalysis_unsupported_case_count = sum(part$reanalysis_status == "unsupported"),
      baseline_top_k_recall = if (length(baseline_rank)) mean(baseline_rank <= top_k) else NA_real_,
      reanalysis_top_k_recall = if (length(reanalysis_rank)) mean(reanalysis_rank <= top_k) else NA_real_,
      top_k_recall_delta = if (length(baseline_rank)) {
        mean(reanalysis_rank <= top_k) - mean(baseline_rank <= top_k)
      } else NA_real_,
      recovered_gain_count = sum(!is.finite(baseline_rank) & is.finite(reanalysis_rank)),
      recovered_loss_count = sum(is.finite(baseline_rank) & !is.finite(reanalysis_rank)),
      rank_improved_count = sum(is.finite(baseline_rank) & is.finite(reanalysis_rank) &
                                  reanalysis_rank < baseline_rank),
      mean_reciprocal_rank_delta = if (length(baseline_rank)) {
        mean(ifelse(is.finite(reanalysis_rank), 1 / reanalysis_rank, 0)) -
          mean(ifelse(is.finite(baseline_rank), 1 / baseline_rank, 0))
      } else NA_real_,
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, out)
}
