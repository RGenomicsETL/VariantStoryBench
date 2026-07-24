bench_manifest_kinds <- c(
  "cases", "truth", "runs", "evaluations", "candidates", "judgments",
  "judgment_sources"
)

bench_nonempty_text <- function(x, name) {
  if (!is.character(x) || anyNA(x) || any(!nzchar(x))) {
    stop(name, " must contain non-empty strings", call. = FALSE)
  }
}

bench_integer_values <- function(x, name, minimum = 0L) {
  if (!is.numeric(x) || anyNA(x) ||
      any(x < minimum | x != floor(x) | x > 2147483647)) {
    stop(
      name, " must contain integers greater than or equal to ", minimum,
      call. = FALSE
    )
  }
}

bench_nonnegative_values <- function(x, name, missing = FALSE) {
  if (!is.numeric(x) || (!missing && anyNA(x)) ||
      any(x[!is.na(x)] < 0 | !is.finite(x[!is.na(x)]))) {
    stop(name, " must contain non-negative finite values", call. = FALSE)
  }
}

bench_choice_values <- function(x, choices, name) {
  bench_nonempty_text(x, name)
  unknown <- setdiff(unique(x), choices)
  if (length(unknown)) {
    stop(
      name, " contains unsupported values: ",
      paste(unknown, collapse = ", "),
      call. = FALSE
    )
  }
}

bench_unique_key <- function(x, columns, name) {
  key <- do.call(paste, c(x[columns], sep = "\034"))
  if (anyDuplicated(key)) {
    stop(
      name, " must be unique by ", paste(columns, collapse = ", "),
      call. = FALSE
    )
  }
}

#' Validate benchmark case units
#'
#' A row is one evaluation unit. A biological case may therefore occur once
#' for variant ranking and once for gene ranking. `truth_status` distinguishes
#' a known causal answer from an unresolved case and a genuinely confirmed
#' negative case.
#'
#' @param cases Data frame with `case_id`, `cohort`, `target_type`, and
#'   `truth_status`.
#' @return `cases`, invisibly.
#' @export
bench_validate_cases <- function(cases) {
  if (!is.data.frame(cases)) stop("cases must be a data frame", call. = FALSE)
  bench_required_columns(
    cases, c("case_id", "cohort", "target_type", "truth_status")
  )
  bench_nonempty_text(cases$case_id, "cases$case_id")
  bench_nonempty_text(cases$cohort, "cases$cohort")
  bench_choice_values(
    cases$target_type, c("variant", "variant_set", "gene"),
    "cases$target_type"
  )
  bench_choice_values(
    cases$truth_status, c("known_causal", "unresolved", "confirmed_negative"),
    "cases$truth_status"
  )
  bench_unique_key(cases, c("case_id", "target_type"), "cases")
  invisible(cases)
}

#' Validate causal-answer rows
#'
#' @param truth Data frame with `case_id`, `target_type`, and `causal_id`.
#'   Multiple causal rows are allowed for one case unit.
#' @return `truth`, invisibly.
#' @export
bench_validate_truth <- function(truth) {
  if (!is.data.frame(truth)) stop("truth must be a data frame", call. = FALSE)
  bench_required_columns(truth, c("case_id", "target_type", "causal_id"))
  bench_nonempty_text(truth$case_id, "truth$case_id")
  bench_choice_values(
    truth$target_type, c("variant", "variant_set", "gene"),
    "truth$target_type"
  )
  bench_nonempty_text(truth$causal_id, "truth$causal_id")
  bench_unique_key(
    truth, c("case_id", "target_type", "causal_id"), "truth"
  )
  invisible(truth)
}

#' Validate benchmark run receipts
#'
#' @param runs Data frame with one row per run. Required columns identify the
#'   engine and exact source, profile, knowledge cutoff, thread count, measured
#'   wall time and peak resident memory, and overall run status.
#' @return `runs`, invisibly.
#' @export
bench_validate_runs <- function(runs) {
  if (!is.data.frame(runs)) stop("runs must be a data frame", call. = FALSE)
  bench_required_columns(
    runs,
    c(
      "run_id", "engine_id", "engine_version", "source_revision",
      "profile_id", "knowledge_cutoff", "thread_count", "wall_seconds",
      "peak_rss_bytes", "run_status"
    )
  )
  for (column in c(
    "run_id", "engine_id", "engine_version", "source_revision", "profile_id"
  )) {
    bench_nonempty_text(runs[[column]], paste0("runs$", column))
  }
  parsed_dates <- as.Date(runs$knowledge_cutoff)
  if (anyNA(parsed_dates)) {
    stop("runs$knowledge_cutoff must contain ISO calendar dates", call. = FALSE)
  }
  bench_integer_values(runs$thread_count, "runs$thread_count", minimum = 1L)
  bench_nonnegative_values(runs$wall_seconds, "runs$wall_seconds")
  bench_nonnegative_values(
    runs$peak_rss_bytes, "runs$peak_rss_bytes", missing = TRUE
  )
  bench_choice_values(
    runs$run_status, c("completed", "failed"), "runs$run_status"
  )
  bench_unique_key(runs, "run_id", "runs")
  invisible(runs)
}

#' Validate per-case execution coverage
#'
#' @param evaluations Data frame with `run_id`, `case_id`, `target_type`, and
#'   `status`. Every run must have one row for every case unit before metrics
#'   are calculated.
#' @return `evaluations`, invisibly.
#' @export
bench_validate_evaluations <- function(evaluations) {
  if (!is.data.frame(evaluations)) {
    stop("evaluations must be a data frame", call. = FALSE)
  }
  bench_required_columns(
    evaluations, c("run_id", "case_id", "target_type", "status")
  )
  bench_nonempty_text(evaluations$run_id, "evaluations$run_id")
  bench_nonempty_text(evaluations$case_id, "evaluations$case_id")
  bench_choice_values(
    evaluations$target_type, c("variant", "variant_set", "gene"),
    "evaluations$target_type"
  )
  bench_choice_values(
    evaluations$status, c("completed", "failed", "unsupported", "skipped"),
    "evaluations$status"
  )
  bench_unique_key(
    evaluations, c("run_id", "case_id", "target_type"), "evaluations"
  )
  invisible(evaluations)
}

#' Validate ranked candidate rows
#'
#' @param candidates Data frame with `run_id`, `case_id`, `target_type`,
#'   `candidate_id`, and positive integer `rank`.
#' @return `candidates`, invisibly.
#' @export
bench_validate_candidates <- function(candidates) {
  if (!is.data.frame(candidates)) {
    stop("candidates must be a data frame", call. = FALSE)
  }
  bench_required_columns(
    candidates,
    c("run_id", "case_id", "target_type", "candidate_id", "rank")
  )
  bench_nonempty_text(candidates$run_id, "candidates$run_id")
  bench_nonempty_text(candidates$case_id, "candidates$case_id")
  bench_choice_values(
    candidates$target_type, c("variant", "variant_set", "gene"),
    "candidates$target_type"
  )
  bench_nonempty_text(candidates$candidate_id, "candidates$candidate_id")
  bench_integer_values(candidates$rank, "candidates$rank", minimum = 1L)
  bench_unique_key(
    candidates,
    c("run_id", "case_id", "target_type", "candidate_id"),
    "candidates"
  )
  invisible(candidates)
}

#' Read and validate a benchmark manifest
#'
#' @param path CSV file path.
#' @param kind One of `"cases"`, `"truth"`, `"runs"`, `"evaluations"`,
#'   `"candidates"`, `"judgments"`, or `"judgment_sources"`.
#' @return A validated data frame.
#' @export
bench_read_manifest <- function(path, kind) {
  path <- bench_path(path, "path", must_exist = TRUE)
  if (!is.character(kind) || length(kind) != 1L || is.na(kind) ||
      !kind %in% bench_manifest_kinds) {
    stop(
      "kind must be one of: ", paste(bench_manifest_kinds, collapse = ", "),
      call. = FALSE
    )
  }
  value <- utils::read.csv(
    path, stringsAsFactors = FALSE, check.names = FALSE, na.strings = c("", "NA")
  )
  validator <- get(
    paste0("bench_validate_", kind), envir = asNamespace("VariantStoryBench")
  )
  validator(value)
  value
}

bench_manifest_relations <- function(cases, truth, runs, evaluations,
                                     candidates) {
  bench_validate_cases(cases)
  bench_validate_truth(truth)
  bench_validate_runs(runs)
  bench_validate_evaluations(evaluations)
  bench_validate_candidates(candidates)

  case_key <- c("case_id", "target_type")
  known <- cases[cases$truth_status == "known_causal", case_key, drop = FALSE]
  unresolved <- cases[cases$truth_status != "known_causal", case_key, drop = FALSE]
  truth_known <- merge(truth, known, by = case_key)
  if (nrow(truth_known) != nrow(truth)) {
    stop("truth rows must refer only to known_causal case units", call. = FALSE)
  }
  known_with_truth <- unique(truth[case_key])
  if (nrow(merge(known, known_with_truth, by = case_key)) != nrow(known)) {
    stop("every known_causal case unit requires at least one truth row",
         call. = FALSE)
  }
  if (nrow(unresolved) &&
      nrow(merge(truth, unresolved, by = case_key))) {
    stop("unresolved and confirmed_negative case units cannot have truth rows",
         call. = FALSE)
  }

  expected <- merge(
    runs["run_id"], cases[case_key], by = NULL
  )
  observed <- evaluations[c("run_id", case_key)]
  if (nrow(merge(expected, observed, by = c("run_id", case_key))) !=
      nrow(expected) || nrow(observed) != nrow(expected)) {
    stop("evaluations must contain every run and case unit exactly once",
         call. = FALSE)
  }

  if (nrow(candidates)) {
    candidate_coverage <- merge(
      candidates,
      evaluations,
      by = c("run_id", case_key)
    )
    if (nrow(candidate_coverage) != nrow(candidates)) {
      stop("every candidate row must refer to a declared evaluation",
           call. = FALSE)
    }
    if (any(candidate_coverage$status != "completed")) {
      stop("candidate rows require a completed evaluation", call. = FALSE)
    }
  }
  invisible(TRUE)
}

bench_mean_or_na <- function(x) {
  if (length(x)) mean(x) else NA_real_
}

#' Calculate comparable ranking and coverage metrics
#'
#' Metrics use every declared case unit. Failed or unsupported known-causal
#' cases count as misses rather than disappearing from the denominator.
#' Unresolved cases are reported as candidate burden, not false positives.
#'
#' @param cases,truth,runs,evaluations,candidates Validated benchmark
#'   manifests.
#' @param top_k Positive integer recall cutoffs.
#' @param by Case columns used to stratify results. The default keeps gene,
#'   variant, and variant-set tasks separate.
#' @return A data frame with one row per run and requested stratum.
#' @export
bench_rank_metrics <- function(
    cases, truth, runs, evaluations, candidates,
    top_k = c(1L, 3L, 5L, 10L), by = "target_type") {
  bench_manifest_relations(cases, truth, runs, evaluations, candidates)
  bench_integer_values(top_k, "top_k", minimum = 1L)
  top_k <- sort(unique(as.integer(top_k)))
  if (!is.character(by) || anyNA(by) ||
      any(!by %in% setdiff(names(cases), c("case_id", "truth_status")))) {
    stop("by must name case-manifest columns other than case_id and truth_status",
         call. = FALSE)
  }

  unit <- merge(
    evaluations, cases,
    by = c("case_id", "target_type"),
    all.x = TRUE, sort = FALSE
  )
  candidate_count <- if (nrow(candidates)) {
    value <- stats::aggregate(
      candidates$candidate_id,
      candidates[c("run_id", "case_id", "target_type")],
      length
    )
    names(value)[[4L]] <- "candidate_count"
    value
  } else {
    data.frame(
      run_id = character(),
      case_id = character(),
      target_type = character(),
      candidate_count = integer()
    )
  }
  unit <- merge(
    unit, candidate_count,
    by = c("run_id", "case_id", "target_type"),
    all.x = TRUE, sort = FALSE
  )
  unit$candidate_count[is.na(unit$candidate_count)] <- 0L

  causal <- merge(
    candidates, truth,
    by = c("case_id", "target_type"),
    suffixes = c("", "_truth")
  )
  causal <- causal[causal$candidate_id == causal$causal_id, , drop = FALSE]
  if (nrow(causal)) {
    causal_rank <- stats::aggregate(
      causal$rank,
      causal[c("run_id", "case_id", "target_type")],
      min
    )
    names(causal_rank)[[4L]] <- "causal_rank"
    unit <- merge(
      unit, causal_rank,
      by = c("run_id", "case_id", "target_type"),
      all.x = TRUE, sort = FALSE
    )
  } else {
    unit$causal_rank <- NA_real_
  }

  group_columns <- c("run_id", by)
  group_key <- do.call(paste, c(unit[group_columns], sep = "\034"))
  pieces <- split(unit, group_key, drop = TRUE)
  rows <- lapply(pieces, function(part) {
    run <- runs[runs$run_id == part$run_id[[1L]], , drop = FALSE]
    known <- part$truth_status == "known_causal"
    completed <- part$status == "completed"
    rank <- part$causal_rank[known]
    rank[is.na(rank)] <- Inf
    candidate_part <- merge(
      candidates[candidates$run_id == part$run_id[[1L]], , drop = FALSE],
      unique(part[c("case_id", "target_type")]),
      by = c("case_id", "target_type")
    )

    out <- c(
      as.list(run[c(
        "run_id", "engine_id", "engine_version", "source_revision",
        "profile_id", "knowledge_cutoff", "thread_count", "wall_seconds",
        "peak_rss_bytes", "run_status"
      )]),
      as.list(part[1L, by, drop = FALSE]),
      list(
        case_count = nrow(part),
        completed_case_count = sum(completed),
        failed_case_count = sum(part$status == "failed"),
        unsupported_case_count = sum(part$status == "unsupported"),
        skipped_case_count = sum(part$status == "skipped"),
        known_causal_case_count = sum(known),
        recovered_causal_case_count = sum(is.finite(rank)),
        unresolved_case_count = sum(part$truth_status == "unresolved"),
        confirmed_negative_case_count =
          sum(part$truth_status == "confirmed_negative"),
        mean_reciprocal_rank = if (length(rank)) {
          mean(ifelse(is.finite(rank), 1 / rank, 0))
        } else {
          NA_real_
        },
        mean_candidate_burden = bench_mean_or_na(
          part$candidate_count[completed]
        ),
        unresolved_candidate_burden = bench_mean_or_na(
          part$candidate_count[
            completed & part$truth_status == "unresolved"
          ]
        ),
        confirmed_negative_candidate_burden = bench_mean_or_na(
          part$candidate_count[
            completed & part$truth_status == "confirmed_negative"
          ]
        )
      )
    )
    for (k in top_k) {
      out[[paste0("top_", k, "_recall")]] <- if (length(rank)) {
        mean(rank <= k)
      } else {
        NA_real_
      }
      at_k <- candidate_part[candidate_part$rank <= k, , drop = FALSE]
      counts <- if (nrow(at_k)) {
        stats::aggregate(
          at_k$candidate_id,
          at_k[c("case_id", "target_type")],
          length
        )
      } else {
        data.frame(
          case_id = character(), target_type = character(), x = integer()
        )
      }
      completed_units <- part[completed, c("case_id", "target_type"), drop = FALSE]
      burden <- merge(
        completed_units, counts,
        by = c("case_id", "target_type"), all.x = TRUE
      )$x
      burden[is.na(burden)] <- 0L
      out[[paste0("top_", k, "_candidate_burden")]] <-
        bench_mean_or_na(burden)
    }
    as.data.frame(out, stringsAsFactors = FALSE, check.names = FALSE)
  })
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out[do.call(order, out[c("run_id", by)]), , drop = FALSE]
}
