#' Consume DuckSemantics hypothesis observations
#'
#' Maps validated DuckSemantics hypotheses to the benchmark's existing
#' `judgments` and `judgment_sources` relations. Abstentions remain candidates
#' without judgments, which is the benchmark's abstention contract.
#'
#' @param hypotheses DuckSemantics hypothesis observations.
#' @param sources DuckSemantics hypothesis source links.
#' @param source_fields Versioned source fields used to validate exact spans.
#' @param candidates Benchmark candidate relation.
#'
#' @return A named list containing the validated benchmark relations, the
#'   original hypothesis receipts, and explicit abstention keys.
#' @export
bench_ducksemantics_grounding <- function(hypotheses, sources, source_fields,
                                          candidates) {
  bundle <- ducksemantics::ducksemantics_hypotheses(
    hypotheses,
    sources,
    source_fields
  )
  observed <- bundle$hypotheses$judgment != "abstain"
  emitted <- bundle$hypotheses[observed, , drop = FALSE]

  judgments <- data.frame(
    run_id = emitted$run_id,
    case_id = emitted$case_id,
    target_type = emitted$target_type,
    candidate_id = emitted$candidate_id,
    claim_id = emitted$hypothesis_id,
    claim_text = emitted$claim_text,
    judgment = emitted$judgment,
    judge_id = emitted$proposer_id,
    judge_version = emitted$proposer_version,
    confidence = emitted$confidence,
    stringsAsFactors = FALSE
  )

  source_rows <- bundle$sources$hypothesis_id %in% emitted$hypothesis_id
  emitted_sources <- bundle$sources[source_rows, , drop = FALSE]
  judgment_sources <- data.frame(
    run_id = emitted$run_id[match(emitted_sources$hypothesis_id, emitted$hypothesis_id)],
    case_id = emitted$case_id[match(emitted_sources$hypothesis_id, emitted$hypothesis_id)],
    target_type = emitted$target_type[match(emitted_sources$hypothesis_id, emitted$hypothesis_id)],
    candidate_id = emitted$candidate_id[match(emitted_sources$hypothesis_id, emitted$hypothesis_id)],
    claim_id = emitted_sources$hypothesis_id,
    source_relation = emitted_sources$source_relation,
    source_release = emitted_sources$release_id,
    source_record_id = emitted_sources$source_record_id,
    source_field = emitted_sources$source_field,
    span_start = emitted_sources$start_offset,
    span_end = emitted_sources$end_offset,
    stance = c(
      support = "supports",
      contradiction = "contradicts",
      context = "context"
    )[emitted_sources$evidence_role],
    stringsAsFactors = FALSE
  )

  bench_validate_grounding(judgments, judgment_sources, candidates)

  abstained <- bundle$hypotheses[!observed, c(
    "hypothesis_id", "run_id", "case_id", "target_type", "candidate_id"
  ), drop = FALSE]
  rownames(abstained) <- NULL

  list(
    judgments = judgments,
    judgment_sources = judgment_sources,
    hypotheses = bundle$hypotheses,
    hypothesis_sources = bundle$sources,
    abstentions = abstained
  )
}
