bench_classification_level <- function(x) {
  value <- tolower(trimws(as.character(x)))
  value <- gsub("[ /-]+", "_", value)
  aliases <- c(
    "benign" = "benign",
    "likely_benign" = "likely_benign",
    "vus" = "vus",
    "uncertain_significance" = "vus",
    "variant_of_uncertain_significance" = "vus",
    "likely_pathogenic" = "likely_pathogenic",
    "pathogenic" = "pathogenic",
    "conflicting" = "conflicting",
    "conflicting_classifications_of_pathogenicity" = "conflicting"
  )
  out <- unname(aliases[value])
  out[is.na(value)] <- NA_character_
  out[is.na(out) & !is.na(value)] <- "other"
  out
}

bench_classification_transition <- function(left, right) {
  out <- rep("other_change", length(left))
  out[is.na(left) & !is.na(right)] <- "added"
  out[!is.na(left) & is.na(right)] <- "removed"
  out[!is.na(left) & !is.na(right) & left == right] <- "stable"

  left_pathogenic <- left %in% c("pathogenic", "likely_pathogenic")
  right_pathogenic <- right %in% c("pathogenic", "likely_pathogenic")
  left_benign <- left %in% c("benign", "likely_benign")
  right_benign <- right %in% c("benign", "likely_benign")
  left_uncertain <- left %in% c("vus", "conflicting")
  right_uncertain <- right %in% c("vus", "conflicting")

  out[left_uncertain & right_pathogenic] <- "resolved_pathogenic"
  out[left_uncertain & right_benign] <- "resolved_benign"
  out[(left_pathogenic | left_benign) & right_uncertain] <- "became_uncertain"
  out[(left_pathogenic & right_benign) |
        (left_benign & right_pathogenic)] <- "direction_reversal"
  out[left_pathogenic & right_pathogenic & left != right] <-
    "pathogenic_strength_change"
  out[left_benign & right_benign & left != right] <-
    "benign_strength_change"
  out
}

bench_validate_classification_decisions <- function(decisions) {
  if (!is.data.frame(decisions)) {
    stop("decisions must be a data frame", call. = FALSE)
  }
  bench_required_columns(
    decisions,
    c(
      "release_id", "policy_receipt", "allele_id", "disease_key",
      "classification"
    )
  )
  for (column in c(
    "release_id", "policy_receipt", "allele_id", "disease_key",
    "classification"
  )) {
    bench_nonempty_text(
      as.character(decisions[[column]]), paste0("decisions$", column)
    )
  }
  bench_unique_key(
    decisions,
    c("release_id", "policy_receipt", "allele_id", "disease_key"),
    "decisions"
  )
  invisible(decisions)
}

bench_scalar_manifest_value <- function(value, name) {
  if (!is.character(value) || length(value) != 1L || is.na(value) ||
      !nzchar(value)) {
    stop(name, " must be one non-empty string", call. = FALSE)
  }
  value
}

#' Compare classification decisions across one declared axis
#'
#' Compares either two releases under the same submitter-policy receipt or two
#' submitter policies on the same release. Changing both at once is rejected
#' because source evolution and policy sensitivity would be confounded.
#'
#' @param decisions Data frame with `release_id`, `policy_receipt`,
#'   `allele_id`, `disease_key`, and `classification`. Optional `gold_stars`
#'   are carried into the result.
#' @param left_release,right_release Release identifiers.
#' @param left_policy,right_policy Policy receipts. A receipt must identify the
#'   arbitration implementation, named profile, and submitter exclusions used
#'   to produce the decision relation.
#' @return One row per disease-level allele decision in the union of the two
#'   selected snapshots.
#' @export
bench_classification_diff <- function(
    decisions,
    left_release, left_policy,
    right_release, right_policy) {
  bench_validate_classification_decisions(decisions)
  left_release <- bench_scalar_manifest_value(left_release, "left_release")
  right_release <- bench_scalar_manifest_value(right_release, "right_release")
  left_policy <- bench_scalar_manifest_value(left_policy, "left_policy")
  right_policy <- bench_scalar_manifest_value(right_policy, "right_policy")

  release_changed <- left_release != right_release
  policy_changed <- left_policy != right_policy
  if (release_changed && policy_changed) {
    stop(
      "change either release or policy, not both, in one comparison",
      call. = FALSE
    )
  }
  if (!release_changed && !policy_changed) {
    stop("the selected snapshots are identical", call. = FALSE)
  }
  comparison_kind <- if (release_changed) {
    "temporal_release"
  } else {
    "submitter_policy"
  }

  key <- c("allele_id", "disease_key")
  columns <- c(key, "classification")
  if ("gold_stars" %in% names(decisions)) {
    bench_integer_values(
      decisions$gold_stars, "decisions$gold_stars", minimum = 0L
    )
    columns <- c(columns, "gold_stars")
  }
  left <- decisions[
    decisions$release_id == left_release &
      decisions$policy_receipt == left_policy,
    columns,
    drop = FALSE
  ]
  right <- decisions[
    decisions$release_id == right_release &
      decisions$policy_receipt == right_policy,
    columns,
    drop = FALSE
  ]
  if (!nrow(left) || !nrow(right)) {
    stop("both selected decision snapshots must contain rows", call. = FALSE)
  }

  names(left)[names(left) == "classification"] <- "left_classification"
  names(right)[names(right) == "classification"] <- "right_classification"
  if ("gold_stars" %in% names(left)) {
    names(left)[names(left) == "gold_stars"] <- "left_gold_stars"
    names(right)[names(right) == "gold_stars"] <- "right_gold_stars"
  }
  out <- merge(left, right, by = key, all = TRUE, sort = TRUE)
  out$left_level <- bench_classification_level(out$left_classification)
  out$right_level <- bench_classification_level(out$right_classification)
  out$transition <- bench_classification_transition(
    out$left_level, out$right_level
  )
  out$comparison_kind <- comparison_kind
  out$left_release <- left_release
  out$right_release <- right_release
  out$left_policy <- left_policy
  out$right_policy <- right_policy
  output_columns <- c(
    "comparison_kind", "left_release", "right_release", "left_policy",
    "right_policy", key, "left_classification", "right_classification"
  )
  if ("left_gold_stars" %in% names(out)) {
    output_columns <- c(
      output_columns, "left_gold_stars", "right_gold_stars"
    )
  }
  output_columns <- c(
    output_columns, "left_level", "right_level", "transition"
  )
  out[output_columns]
}

#' Summarize classification changes
#'
#' @param changes Result from [bench_classification_diff()].
#' @return Counts and proportions by comparison kind and transition.
#' @export
bench_classification_diff_summary <- function(changes) {
  bench_required_columns(changes, c("comparison_kind", "transition"))
  counts <- stats::aggregate(
    rep.int(1L, nrow(changes)),
    changes[c("comparison_kind", "transition")],
    sum
  )
  names(counts)[[3L]] <- "decision_count"
  total <- stats::aggregate(
    counts$decision_count,
    counts["comparison_kind"],
    sum
  )
  names(total)[[2L]] <- "total_decision_count"
  out <- merge(counts, total, by = "comparison_kind")
  out$proportion <- out$decision_count / out$total_decision_count
  out[order(out$comparison_kind, out$transition), , drop = FALSE]
}
