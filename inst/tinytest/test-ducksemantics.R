local({
  field_text <- "Reduced fibrillin changes extracellular matrix signaling."
  source_fields <- data.frame(
    provider_id = "DisMech",
    release_id = "fixture-release",
    source_id = "dismech-fixture",
    source_row_id = "MONDO:0007947",
    field_path = "/pathophysiology/0/description",
    value = field_text,
    stringsAsFactors = FALSE
  )
  hypothesis <- data.frame(
    hypothesis_id = "hypothesis-1",
    run_id = "run-1",
    case_id = "case-1",
    target_type = "gene",
    candidate_id = "HGNC:3603",
    proposal_type = "candidate",
    claim_text = field_text,
    inheritance_id = "HP:0000006",
    mechanism_text = "Reduced extracellular matrix signaling",
    proposer_type = "model",
    proposer_id = "fixture-model",
    proposer_version = "1",
    confidence = 0.9,
    judgment = "supports",
    missing_evidence = NA_character_,
    contradiction = NA_character_,
    review_status = "accepted",
    reviewer_id = "reviewer-1",
    reviewed_at = as.POSIXct("2026-01-02", tz = "UTC"),
    review_note = "The cited span supports the proposed mechanism.",
    supersedes_id = NA_character_,
    recorded_at = as.POSIXct("2026-01-01", tz = "UTC"),
    stringsAsFactors = FALSE
  )
  source <- data.frame(
    hypothesis_id = "hypothesis-1",
    provider_id = "DisMech",
    release_id = "fixture-release",
    source_id = "dismech-fixture",
    source_relation = "dismech_fields",
    source_record_id = "MONDO:0007947",
    source_field = "/pathophysiology/0/description",
    start_offset = 0L,
    end_offset = nchar(field_text, type = "chars"),
    source_span = field_text,
    citation = "fixture:MONDO:0007947",
    evidence_role = "support",
    stringsAsFactors = FALSE
  )
  candidates <- data.frame(
    run_id = "run-1",
    case_id = "case-1",
    target_type = "gene",
    candidate_id = "HGNC:3603",
    rank = 1L,
    score = 0.9,
    stringsAsFactors = FALSE
  )
  consumed <- VariantStoryBench::bench_ducksemantics_grounding(
    hypothesis,
    source,
    source_fields,
    candidates
  )
  expect_equal(consumed$judgments$claim_id, "hypothesis-1")
  expect_equal(consumed$judgment_sources$source_release, "fixture-release")
  expect_equal(consumed$judgment_sources$stance, "supports")
  expect_equal(consumed$hypothesis_sources$source_span, field_text)
  expect_equal(nrow(consumed$abstentions), 0L)

  metrics <- VariantStoryBench::bench_grounding_metrics(
    consumed$judgments,
    consumed$judgment_sources,
    candidates
  )
  expect_equal(metrics$judgment_count, 1L)
  expect_equal(metrics$unique_source_record_count, 1L)

  abstention <- hypothesis
  abstention$confidence <- NA_real_
  abstention$judgment <- "abstain"
  abstention$review_status <- "abstained"
  abstention$reviewer_id <- NA_character_
  abstention$reviewed_at <- as.POSIXct(NA, tz = "UTC")
  abstention$review_note <- NA_character_
  abstention$inheritance_id <- NA_character_
  abstention$mechanism_text <- NA_character_
  consumed <- VariantStoryBench::bench_ducksemantics_grounding(
    abstention,
    source[FALSE, ],
    source_fields,
    candidates
  )
  expect_equal(nrow(consumed$judgments), 0L)
  expect_equal(nrow(consumed$judgment_sources), 0L)
  expect_equal(consumed$abstentions$hypothesis_id, "hypothesis-1")

  invalid <- source
  invalid$source_span <- paste0(invalid$source_span, " altered")
  expect_error(
    VariantStoryBench::bench_ducksemantics_grounding(
      hypothesis,
      invalid,
      source_fields,
      candidates
    ),
    "exactly match"
  )
})
