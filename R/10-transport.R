bench_exact_transport_metrics <- function(truth, observed, key, fields) {
  truth$.truth_row <- TRUE
  observed$.observed_row <- TRUE
  joined <- merge(
    truth, observed, by = key, all = TRUE, suffixes = c(".truth", ".observed"),
    sort = FALSE
  )
  matched <- !is.na(joined$.truth_row) & !is.na(joined$.observed_row)
  exact <- matched
  for (field in fields) {
    left <- joined[[paste0(field, ".truth")]]
    right <- joined[[paste0(field, ".observed")]]
    same <- (is.na(left) & is.na(right)) |
      (!is.na(left) & !is.na(right) & left == right)
    exact <- exact & same
  }
  truth_count <- nrow(truth)
  exact_count <- sum(exact)
  data.frame(
    truth_row_count = truth_count,
    observed_row_count = nrow(observed),
    identity_matched_row_count = sum(matched),
    exact_row_count = exact_count,
    missing_row_count = sum(!is.na(joined$.truth_row) & is.na(joined$.observed_row)),
    unexpected_row_count = sum(is.na(joined$.truth_row) & !is.na(joined$.observed_row)),
    exact_recall = if (truth_count) exact_count / truth_count else NA_real_,
    stringsAsFactors = FALSE
  )
}

#' Evaluate source-to-canonical allele transport
#'
#' Compares an engine-neutral allele observation relation with sealed evaluator
#' truth by case, source-record ordinal, and ALT ordinal. Source and canonical
#' geometry, assembly, sequence class, and admission status must all agree for
#' an exact row.
#'
#' @param allele_truth Sealed allele truth relation.
#' @param observations Engine-emitted allele observations with the same schema.
#' @return One-row coverage and exactness metrics.
#' @export
bench_allele_transport_metrics <- function(allele_truth, observations) {
  bench_validate_allele_truth(allele_truth, "allele_truth")
  bench_validate_allele_truth(observations, "allele observations")
  key <- c("case_id", "record_ordinal", "alt_ordinal")
  fields <- setdiff(names(allele_truth), key)
  bench_exact_transport_metrics(allele_truth, observations, key, fields)
}

#' Evaluate genotype transport
#'
#' Compares exact GT, GQ, DP, ploidy, phase, and call-state transport at
#' case/person/source-record/ALT grain. The validator derives ploidy, phase, and
#' call state from GT before scoring, so internally contradictory observations
#' fail rather than receiving partial credit.
#'
#' @param genotype_truth Sealed genotype truth relation.
#' @param observations Engine-emitted genotype observations with the same
#'   schema.
#' @return One-row coverage and exactness metrics.
#' @export
bench_genotype_transport_metrics <- function(genotype_truth, observations) {
  bench_validate_genotype_truth(genotype_truth, "genotype_truth")
  bench_validate_genotype_truth(observations, "genotype observations")
  key <- c("case_id", "person_id", "record_ordinal", "alt_ordinal")
  fields <- setdiff(names(genotype_truth), key)
  bench_exact_transport_metrics(genotype_truth, observations, key, fields)
}
