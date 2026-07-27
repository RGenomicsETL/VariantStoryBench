bench_judgment_key <- c(
  "run_id", "case_id", "target_type", "candidate_id", "claim_id"
)

#' Validate source-grounded candidate judgments
#'
#' A judgment is an auditable claim about one ranked candidate. It may be
#' produced by deterministic rules or a declared local model, but it is not
#' evidence until [bench_validate_grounding()] connects it to exact source
#' records.
#'
#' @param judgments Data frame with run, case, target, candidate and claim
#'   identifiers; claim text; a `supports`, `contradicts`, or
#'   `insufficient_evidence` judgment; judge identity and version; and an
#'   optional confidence in the closed interval from zero to one.
#' @return `judgments`, invisibly.
#' @export
bench_validate_judgments <- function(judgments) {
  if (!is.data.frame(judgments)) {
    stop("judgments must be a data frame", call. = FALSE)
  }
  bench_required_columns(
    judgments,
    c(
      bench_judgment_key, "claim_text", "judgment", "judge_id",
      "judge_version", "confidence"
    )
  )
  for (column in c(
    "run_id", "case_id", "candidate_id", "claim_id", "claim_text",
    "judge_id", "judge_version"
  )) {
    bench_nonempty_text(
      judgments[[column]], paste0("judgments$", column)
    )
  }
  bench_choice_values(
    judgments$target_type, c("variant", "variant_set", "gene", "cnv"),
    "judgments$target_type"
  )
  bench_choice_values(
    judgments$judgment,
    c("supports", "contradicts", "insufficient_evidence"),
    "judgments$judgment"
  )
  if (!is.numeric(judgments$confidence) ||
      any(!is.na(judgments$confidence) &
          (!is.finite(judgments$confidence) |
           judgments$confidence < 0 | judgments$confidence > 1))) {
    stop(
      "judgments$confidence must contain values from zero to one or NA",
      call. = FALSE
    )
  }
  bench_unique_key(judgments, bench_judgment_key, "judgments")
  invisible(judgments)
}

bench_validate_source_spans <- function(start, end) {
  bench_validate_half_open_spans(start, end, "source")
}

#' Validate exact source records for candidate judgments
#'
#' Structured sources may identify an exact row and field with missing text
#' spans. Narrative sources additionally use zero-based, half-open
#' `span_start` and `span_end` offsets within that field.
#'
#' @param judgment_sources Data frame with the judgment key, source relation,
#'   release, record and field identifiers, optional text spans, and source
#'   stance.
#' @return `judgment_sources`, invisibly.
#' @export
bench_validate_judgment_sources <- function(judgment_sources) {
  if (!is.data.frame(judgment_sources)) {
    stop("judgment_sources must be a data frame", call. = FALSE)
  }
  bench_required_columns(
    judgment_sources,
    c(
      bench_judgment_key, "source_relation", "source_release",
      "source_record_id", "source_field", "span_start", "span_end", "stance"
    )
  )
  for (column in c(
    "run_id", "case_id", "candidate_id", "claim_id", "source_relation",
    "source_release", "source_record_id", "source_field"
  )) {
    bench_nonempty_text(
      judgment_sources[[column]], paste0("judgment_sources$", column)
    )
  }
  bench_choice_values(
    judgment_sources$target_type, c("variant", "variant_set", "gene", "cnv"),
    "judgment_sources$target_type"
  )
  bench_choice_values(
    judgment_sources$stance, c("supports", "contradicts", "context"),
    "judgment_sources$stance"
  )
  bench_validate_source_spans(
    judgment_sources$span_start, judgment_sources$span_end
  )
  bench_unique_key(
    judgment_sources,
    c(
      bench_judgment_key, "source_relation", "source_release",
      "source_record_id", "source_field", "span_start", "span_end", "stance"
    ),
    "judgment_sources"
  )
  invisible(judgment_sources)
}

#' Validate the source-grounding relation
#'
#' Every judgment must cite at least one exact source record. A `supports` or
#' `contradicts` judgment must cite at least one source with the same stance.
#' An `insufficient_evidence` judgment may cite contextual or conflicting
#' records. If no source was retrieved, the engine must abstain instead of
#' emitting a judgment.
#'
#' @param judgments Validated candidate judgments.
#' @param judgment_sources Validated exact source records.
#' @param candidates Optional ranked candidate manifest. When supplied, every
#'   judgment must refer to an emitted candidate.
#' @return `TRUE`, invisibly.
#' @export
bench_validate_grounding <- function(
    judgments, judgment_sources, candidates = NULL) {
  bench_validate_judgments(judgments)
  bench_validate_judgment_sources(judgment_sources)

  joined <- merge(
    judgments[c(bench_judgment_key, "judgment")],
    judgment_sources[c(bench_judgment_key, "stance")],
    by = bench_judgment_key,
    all.x = TRUE,
    sort = FALSE
  )
  if (anyNA(joined$stance)) {
    stop("every judgment must cite at least one exact source record",
         call. = FALSE)
  }
  source_keys <- unique(judgment_sources[bench_judgment_key])
  if (nrow(merge(source_keys, judgments[bench_judgment_key],
                 by = bench_judgment_key)) != nrow(source_keys)) {
    stop("every judgment source must refer to a declared judgment",
         call. = FALSE)
  }

  directional <- joined$judgment %in% c("supports", "contradicts")
  matched <- joined$judgment == joined$stance
  directional_keys <- unique(joined[directional, bench_judgment_key,
                                    drop = FALSE])
  matched_keys <- unique(joined[directional & matched, bench_judgment_key,
                                drop = FALSE])
  if (nrow(directional_keys) != nrow(matched_keys)) {
    stop(
      "supports and contradicts judgments require a source with matching stance",
      call. = FALSE
    )
  }

  if (!is.null(candidates)) {
    bench_validate_candidates(candidates)
    candidate_key <- c(
      "run_id", "case_id", "target_type", "candidate_id"
    )
    judged_candidates <- unique(judgments[candidate_key])
    emitted_candidates <- unique(candidates[candidate_key])
    if (nrow(merge(judged_candidates, emitted_candidates,
                   by = candidate_key)) != nrow(judged_candidates)) {
      stop("every judgment must refer to an emitted candidate",
           call. = FALSE)
    }
  }
  invisible(TRUE)
}

#' Summarize source-grounded judgments
#'
#' These are audit and coverage summaries, not evidence that a cited source is
#' scientifically relevant or that a judgment is correct. Those questions
#' require separately adjudicated benchmark truth.
#'
#' @param judgments Validated candidate judgments.
#' @param judgment_sources Validated exact source records.
#' @param candidates Optional ranked candidate manifest.
#' @return One row per run with judgment, source and abstention counts.
#' @export
bench_grounding_metrics <- function(
    judgments, judgment_sources, candidates = NULL) {
  bench_validate_grounding(judgments, judgment_sources, candidates)

  source_count <- stats::aggregate(
    judgment_sources$source_record_id,
    judgment_sources[bench_judgment_key],
    length
  )
  names(source_count)[[length(names(source_count))]] <- "source_count"
  claims <- merge(
    judgments, source_count,
    by = bench_judgment_key,
    sort = FALSE
  )
  run_ids <- unique(judgments$run_id)
  out <- lapply(run_ids, function(run_id) {
    run_claims <- claims[claims$run_id == run_id, , drop = FALSE]
    run_sources <- judgment_sources[
      judgment_sources$run_id == run_id, , drop = FALSE
    ]
    data.frame(
      run_id = run_id,
      grounded_candidate_count = length(unique(run_claims$candidate_id)),
      judgment_count = nrow(run_claims),
      supports_count = sum(run_claims$judgment == "supports"),
      contradicts_count = sum(run_claims$judgment == "contradicts"),
      insufficient_evidence_count =
        sum(run_claims$judgment == "insufficient_evidence"),
      mean_sources_per_judgment = mean(run_claims$source_count),
      unique_source_record_count = nrow(unique(run_sources[c(
        "source_relation", "source_release", "source_record_id"
      )])),
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, out)
}
