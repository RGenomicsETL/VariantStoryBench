library(tinytest)

seen_presentation <- list()
provider <- function(presentation) {
  seen_presentation[[presentation$case_id]] <<- presentation
  term_text <- paste(
    paste0(
      presentation$phenotype_plan$hpo_id, " [",
      presentation$phenotype_plan$context_status, "]"
    ),
    collapse = "; "
  )
  source_text <- paste("Configured note:", term_text)
  starts <- vapply(
    presentation$phenotype_plan$hpo_id,
    function(hpo_id) regexpr(hpo_id, source_text, fixed = TRUE)[[1L]] - 1L,
    integer(1)
  )
  list(
    source_text = source_text,
    spans = data.frame(
      hpo_id = presentation$phenotype_plan$hpo_id,
      context_status = presentation$phenotype_plan$context_status,
      start_offset = starts,
      end_offset = starts + nchar(presentation$phenotype_plan$hpo_id),
      stringsAsFactors = FALSE
    )
  )
}

bundle <- bench_generate_micro_cohort(
  tempfile("variantstorybench-micro-"), provider, "test-provider"
)
engine_input <- bundle$engine_input
evaluator_truth <- bundle$evaluator_truth

expect_equal(sort(names(bundle)), c("engine_input", "evaluator_truth"))
expect_equal(sort(names(engine_input)), c(
  "case_manifest", "documents", "generations", "persons", "relationships",
  "vcf_paths"
))
expect_equal(names(engine_input$persons), c(
  "case_id", "person_id", "vcf_sample_id", "is_proband", "sex", "affected"
))
expect_equal(
  engine_input$persons$affected,
  c(
    "affected", "affected", "unaffected", "unaffected", "affected",
    "affected"
  )
)
expect_equal(names(engine_input$relationships), c(
  "case_id", "person_id", "relative_id", "relationship"
))
expect_equal(names(engine_input$documents), c("case_id", "document_id", "source_text"))
expect_false(any(grepl("causal|truth|reference|oracle", names(engine_input))))
expect_false(any(grepl(
  "causal|truth|reference|oracle",
  paste(capture.output(str(engine_input)), collapse = " ")
)))
expect_equal(names(seen_presentation), c(
  "micro-singleton", "micro-trio", "micro-xcnv", "micro-negative"
))
expect_false(any(grepl(
  "causal|truth|reference|oracle",
  paste(capture.output(str(seen_presentation)), collapse = " ")
)))
expect_true(all(file.exists(engine_input$vcf_paths)))
expect_equal(engine_input$relationships$relationship,
             c("biological_parent", "biological_parent"))
expect_equal(engine_input$relationships$relative_id,
             c("MICRO_MOTHER", "MICRO_FATHER"))
expect_equal(
  sort(unique(engine_input$documents$case_id)),
  sort(engine_input$case_manifest$case_id)
)
expect_true(all(tapply(engine_input$persons$is_proband,
                       engine_input$persons$case_id, sum) == 1L))
for (i in seq_len(nrow(engine_input$generations))) {
  samples <- vcfppR::vcftable(
    engine_input$generations$vcf_path[[i]], format = "GQ"
  )$samples
  expected <- engine_input$persons$vcf_sample_id[
    engine_input$persons$case_id == engine_input$generations$case_id[[i]]
  ]
  expect_equal(samples, expected)
}
leaky_input <- engine_input
leaky_input$case_manifest$causal_id <- "must-not-enter-engine-input"
expect_error(
  VariantStoryBench:::bench_validate_engine_input(leaky_input),
  "cannot contain evaluator truth"
)
expect_equal(engine_input$generations$assembly, rep("GRCh38", 4L))
expect_equal(evaluator_truth$truth$causal_id, c(
  "GRCh38:1:100000:C:T:REF", "GRCh38:2:199999:TG:T:ALT1",
  "GRCh38:7:549997:559997:DEL"
))
expect_equal(evaluator_truth$cases$truth_status, c(
  "known_causal", "known_causal", "known_causal", "confirmed_negative"
))
expect_equal(evaluator_truth$causal_allele_truth$allele_role,
             c("reference", "alternate"))
expect_true(is.na(evaluator_truth$causal_allele_truth$alt_ordinal[[1L]]))
expect_equal(evaluator_truth$causal_allele_truth$alt_ordinal[[2L]], 1L)
expect_equal(names(evaluator_truth$allele_truth), c(
  "case_id", "record_ordinal", "alt_ordinal", "assembly", "source_contig",
  "source_position", "source_reference", "source_alternate",
  "canonical_contig", "canonical_position", "canonical_reference",
  "canonical_alternate", "sequence_class", "source_admission_status"
))
expect_equal(names(evaluator_truth$genotype_truth), c(
  "case_id", "person_id", "record_ordinal", "alt_ordinal", "gt", "gq",
  "dp", "alt_count", "ploidy", "phased", "phase_set", "call_status"
))
trimmed <- evaluator_truth$allele_truth[
  evaluator_truth$allele_truth$case_id == "micro-singleton" &
    evaluator_truth$allele_truth$record_ordinal == 2L, , drop = FALSE
]
expect_equal(trimmed$source_reference, "TGC")
expect_equal(trimmed$source_alternate, "TC")
expect_equal(trimmed$canonical_reference, "TG")
expect_equal(trimmed$canonical_alternate, "T")
expect_equal(
  evaluator_truth$genotype_truth$phased[
    evaluator_truth$genotype_truth$case_id == "micro-singleton" &
      evaluator_truth$genotype_truth$record_ordinal == 2L
  ],
  TRUE
)
expect_equal(
  evaluator_truth$genotype_truth$alt_count[
    evaluator_truth$genotype_truth$case_id == "micro-trio" &
      evaluator_truth$genotype_truth$record_ordinal == 3L
  ],
  c(1L, NA_integer_, NA_integer_)
)
expect_true(all(is.na(evaluator_truth$genotype_truth$phase_set)))
expect_equal(
  evaluator_truth$allele_truth$source_admission_status[
    evaluator_truth$allele_truth$sequence_class == "CNV"
  ],
  "unsupported_symbolic"
)
expect_equal(evaluator_truth$cnv_truth$contig, "7")
expect_equal(evaluator_truth$cnv_truth$start, 549997L)
expect_equal(evaluator_truth$cnv_truth$end, 559997L)
expect_equal(evaluator_truth$cnv_truth$routing_status, "routed")
expect_equal(evaluator_truth$cnv_truth$routing_authority, "XCNV")
expect_equal(
  evaluator_truth$cnv_truth$end - evaluator_truth$cnv_truth$start,
  10000L
)
expect_equal(sort(unique(evaluator_truth$hpo_observations$context_status)), c(
  "absent/negated", "family_history", "present", "uncertain"
))
expect_equal(
  names(evaluator_truth$hpo_observations),
  c(
    "case_id", "person_id", "observation_id",
    ducksemantics::ducksemantics_hpo_observation_contract()
  )
)
expect_equal(
  evaluator_truth$hpo_observations$case_id,
  c(rep(c("micro-singleton", "micro-trio"), each = 2L), "micro-negative")
)
expect_equal(
  evaluator_truth$hpo_observations$person_id,
  c(rep(c("MICRO_SINGLETON", "MICRO_PROBAND"), each = 2L), "MICRO_NEGATIVE")
)
expect_equal(anyDuplicated(
  evaluator_truth$hpo_observations[c("case_id", "observation_id")]
), 0L)
expect_equal(
  evaluator_truth$documents$case_id[
    match(evaluator_truth$hpo_observations$document_id,
          evaluator_truth$documents$document_id)
  ],
  c(rep(c("micro-singleton", "micro-trio"), each = 2L), "micro-negative")
)
cnv_document <- evaluator_truth$documents[
  evaluator_truth$documents$case_id == "micro-xcnv", , drop = FALSE
]
expect_equal(nrow(cnv_document), 1L)
expect_true(nzchar(cnv_document$source_text))
expect_equal(
  sum(evaluator_truth$hpo_observations$document_id == cnv_document$document_id),
  0L
)
expect_equal(sum(evaluator_truth$capabilities$status == "unsupported"), 5L)
expect_equal(
  evaluator_truth$capabilities$status[
    evaluator_truth$capabilities$capability_id %in% c(
      "reference_causal_allele_orientation", "confirmed_negative_case"
    )
  ],
  c("supported", "supported")
)
expect_equal(
  evaluator_truth$capabilities$status[
    evaluator_truth$capabilities$capability_id == "broader_cnv_sv"
  ], "unsupported"
)

generation_csv <- tempfile(fileext = ".csv")
utils::write.csv(engine_input$generations, generation_csv, row.names = FALSE)
generations <- bench_read_manifest(generation_csv, "generations")
expect_equal(generations$generation_id, engine_input$generations$generation_id)

singleton_reader <- vcfppR::vcfreader$new(
  engine_input$vcf_paths[["singleton"]]
)
expect_true(grepl(
  "##fileformat=VCFv4.2", singleton_reader$header(), fixed = TRUE
))
singleton <- vcfppR::vcftable(engine_input$vcf_paths[["singleton"]], format = "GQ")
expect_equal(singleton$chr, c("1", "1"))
expect_equal(singleton$pos, c(100000, 100100))
expect_equal(singleton$ref, c("C", "TGC"))
expect_equal(singleton$alt, c("T", "TC"))
expect_equal(as.integer(singleton$GQ[, 1L]), c(99L, 78L))
singleton_lines <- readLines(gzfile(engine_input$vcf_paths[["singleton"]]))
expect_true(any(grepl("0|1:78:31", singleton_lines, fixed = TRUE)))

trio <- vcfppR::vcftable(engine_input$vcf_paths[["trio"]], format = "GQ")
expect_equal(trio$chr, rep("2", 4L))
expect_equal(trio$ref, c("TG", "T", "A", "T"))
expect_equal(trio$alt, c("T", "A", "C", "C"))

trio_gq <- vcfppR::vcftable(engine_input$vcf_paths[["trio"]], format = "GQ")
trio_dp <- vcfppR::vcftable(engine_input$vcf_paths[["trio"]], format = "DP")
expect_equal(trio_gq$samples, c("MICRO_PROBAND", "MICRO_MOTHER", "MICRO_FATHER"))
expect_equal(as.integer(trio_gq$GQ[1L, ]), c(99L, 99L, 99L))
expect_equal(as.integer(trio_dp$DP[1L, ]), c(42L, 39L, 40L))
expect_true(is.na(trio_gq$GQ[3L, 2L]))
expect_equal(as.integer(trio_gq$GQ[4L, ]), c(8L, 7L, 8L))

cnv_table <- vcfppR::vcftable(engine_input$vcf_paths[["symbolic_cnv"]])
expect_equal(cnv_table$chr, "7")
expect_equal(cnv_table$pos, 549997)
expect_equal(cnv_table$ref, "T")
expect_equal(cnv_table$alt, "<DEL>")

cnv_reader <- vcfppR::vcfreader$new(engine_input$vcf_paths[["symbolic_cnv"]])
expect_true(grepl("##reference=GRCh38", cnv_reader$header(), fixed = TRUE))
expect_true(cnv_reader$variant())
expect_true(cnv_reader$isSV())
expect_equal(cnv_reader$alt(), "<DEL>")
expect_equal(cnv_reader$infoInt("END"), 559997L)

hpo <- bench_hpo_metrics(
  evaluator_truth$documents, evaluator_truth$hpo_observations,
  evaluator_truth$hpo_observations
)
expect_equal(hpo$term_truth_count, 5L)
expect_equal(hpo$context_truth_count, 5L)
expect_equal(hpo$span_truth_count, 5L)
expect_equal(hpo$term_recall, 1)
expect_equal(hpo$context_recall, 1)
expect_equal(hpo$span_recall, 1)

transferred_hpo <- evaluator_truth$hpo_observations
transferred_hpo$person_id[[1L]] <- "wrong-person"
transferred <- bench_hpo_metrics(
  evaluator_truth$documents, evaluator_truth$hpo_observations,
  transferred_hpo
)
expect_equal(transferred$term_true_positive_count, 4L)
expect_equal(transferred$term_precision, 0.8)
expect_equal(transferred$term_recall, 0.8)
leaky_bundle <- bundle
leaky_bundle$evaluator_truth$hpo_observations$person_id[[1L]] <- "wrong-person"
expect_error(
  VariantStoryBench:::bench_validate_micro_cohort(leaky_bundle),
  "declared person"
)

bad_source <- evaluator_truth$hpo_observations
bad_source$source_text[[1L]] <- "wrong"
expect_error(
  bench_hpo_metrics(evaluator_truth$documents, bad_source, evaluator_truth$hpo_observations),
  "source_text"
)

wrong_hpo <- evaluator_truth$hpo_observations
wrong_hpo$hpo_id <- sprintf("HP:%07d", seq_len(nrow(wrong_hpo)))
zero_hpo <- bench_hpo_metrics(
  evaluator_truth$documents, evaluator_truth$hpo_observations, wrong_hpo
)
expect_equal(zero_hpo$term_precision, 0)
expect_equal(zero_hpo$term_recall, 0)
expect_equal(zero_hpo$term_f1, 0)
empty_documents <- data.frame(
  case_id = character(), document_id = character(), source_text = character()
)
empty_observations <- evaluator_truth$hpo_observations[FALSE, ]
empty_hpo <- bench_hpo_metrics(empty_documents, empty_observations, empty_observations)
expect_equal(empty_hpo$term_truth_count, 0L)
expect_true(is.na(empty_hpo$term_f1))
expect_false(is.nan(empty_hpo$term_f1))

expect_equal(
  unname(as.integer(table(evaluator_truth$allele_truth$case_id))),
  c(1L, 2L, 4L, 1L)
)
expect_equal(
  unname(as.integer(table(evaluator_truth$genotype_truth$case_id))),
  c(1L, 2L, 12L, 1L)
)
allele_transport <- bench_allele_transport_metrics(
  evaluator_truth$allele_truth, evaluator_truth$allele_truth
)
expect_equal(allele_transport$exact_row_count, 8L)
expect_equal(allele_transport$exact_recall, 1)
wrong_allele <- evaluator_truth$allele_truth
wrong_allele$canonical_alternate[[2L]] <- "G"
wrong_allele_transport <- bench_allele_transport_metrics(
  evaluator_truth$allele_truth, wrong_allele
)
expect_equal(wrong_allele_transport$exact_row_count, 7L)
expect_equal(wrong_allele_transport$exact_recall, 7 / 8)
missing_allele_transport <- bench_allele_transport_metrics(
  evaluator_truth$allele_truth, evaluator_truth$allele_truth[-2L, ]
)
expect_equal(missing_allele_transport$missing_row_count, 1L)

genotype_transport <- bench_genotype_transport_metrics(
  evaluator_truth$genotype_truth, evaluator_truth$genotype_truth
)
expect_equal(genotype_transport$exact_row_count, 16L)
expect_equal(genotype_transport$exact_recall, 1)
wrong_genotype <- evaluator_truth$genotype_truth
wrong_genotype$gq[[1L]] <- 98
wrong_genotype_transport <- bench_genotype_transport_metrics(
  evaluator_truth$genotype_truth, wrong_genotype
)
expect_equal(wrong_genotype_transport$exact_row_count, 15L)
inconsistent_genotype <- evaluator_truth$genotype_truth
inconsistent_genotype$phased[[2L]] <- FALSE
expect_error(
  bench_genotype_transport_metrics(
    evaluator_truth$genotype_truth, inconsistent_genotype
  ),
  "GT conflicts"
)
wrong_alt_count <- evaluator_truth$genotype_truth
wrong_alt_count$alt_count[[1L]] <- 0L
expect_error(
  bench_genotype_transport_metrics(
    evaluator_truth$genotype_truth, wrong_alt_count
  ),
  "ALT count"
)
invalid_phase_set <- evaluator_truth$genotype_truth
invalid_phase_set$phase_set[[1L]] <- "block-1"
expect_error(
  bench_genotype_transport_metrics(
    evaluator_truth$genotype_truth, invalid_phase_set
  ),
  "phase_set"
)
out_of_range_gt <- evaluator_truth$genotype_truth
out_of_range_gt$gt[[1L]] <- "0/2"
expect_error(
  bench_genotype_transport_metrics(
    evaluator_truth$genotype_truth, out_of_range_gt
  ),
  "exceeds the declared source-record ALT count"
)
leaky_allele <- bundle
leaky_allele$evaluator_truth$allele_truth$alt_ordinal[[1L]] <- 2L
expect_error(
  VariantStoryBench:::bench_validate_micro_cohort(leaky_allele),
  "cover every person and admitted allele"
)
conflated_cnv_admission <- bundle
conflated_cnv_admission$evaluator_truth$allele_truth$source_admission_status[
  conflated_cnv_admission$evaluator_truth$allele_truth$sequence_class == "CNV"
] <- "supported"
expect_error(
  VariantStoryBench:::bench_validate_micro_cohort(conflated_cnv_admission),
  "source symbolic admission"
)
missing_cnv_authority <- bundle
missing_cnv_authority$evaluator_truth$cnv_truth$routing_authority <- NA_character_
expect_error(
  VariantStoryBench:::bench_validate_micro_cohort(missing_cnv_authority),
  "require an authority"
)
missing_cnv_route <- bundle
missing_cnv_route$evaluator_truth$cnv_truth <-
  missing_cnv_route$evaluator_truth$cnv_truth[FALSE, ]
expect_error(
  VariantStoryBench:::bench_validate_micro_cohort(missing_cnv_route),
  "same cases"
)
wrong_reference_role <- bundle
wrong_reference_role$evaluator_truth$causal_allele_truth$alt_ordinal[[1L]] <- 1L
expect_error(
  VariantStoryBench:::bench_validate_micro_cohort(wrong_reference_role),
  "reference causal alleles require no ALT ordinal"
)
missing_causal_orientation <- bundle
missing_causal_orientation$evaluator_truth$causal_allele_truth <-
  missing_causal_orientation$evaluator_truth$causal_allele_truth[-1L, ]
expect_error(
  VariantStoryBench:::bench_validate_micro_cohort(missing_causal_orientation),
  "cover exactly variant causal truth"
)
negative_genotype <- evaluator_truth$genotype_truth[
  evaluator_truth$genotype_truth$case_id == "micro-negative", , drop = FALSE
]
expect_equal(negative_genotype$call_status, "called_alternate")
expect_false("micro-negative" %in% evaluator_truth$truth$case_id)
expect_false("micro-negative" %in% evaluator_truth$causal_allele_truth$case_id)

runs <- data.frame(
  run_id = "sealed-fixture",
  engine_id = "declared-fixture",
  engine_version = "1",
  source_revision = "fixture",
  profile_id = "fixture",
  knowledge_cutoff = "2026-07-01",
  thread_count = 1L,
  wall_seconds = 0,
  peak_rss_bytes = NA_real_,
  run_status = "completed"
)
evaluations <- data.frame(
  run_id = "sealed-fixture",
  case_id = evaluator_truth$cases$case_id,
  target_type = evaluator_truth$cases$target_type,
  status = "completed"
)
candidates <- data.frame(
  run_id = "sealed-fixture",
  case_id = evaluator_truth$truth$case_id,
  target_type = evaluator_truth$truth$target_type,
  candidate_id = evaluator_truth$truth$causal_id,
  rank = 1L
)
evaluation <- bench_evaluate_micro_cohort(
  evaluator_truth, runs, evaluations, candidates, top_k = 1L
)
expect_equal(evaluation$known_causal_case_count, c(1L, 2L))
expect_equal(evaluation$target_type, c("cnv", "variant"))
expect_equal(evaluation$top_1_recall, c(1, 1))
expect_equal(evaluation$confirmed_negative_case_count, c(0L, 1L))
expect_equal(evaluation$confirmed_negative_candidate_burden, c(NA, 0))

if (requireNamespace("Rduckhts", quietly = TRUE) &&
    requireNamespace("DBI", quietly = TRUE)) {
  con <- Rduckhts::rduckhts_connect()
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  expected_rows <- c(
    singleton = 2L, trio = 4L, symbolic_cnv = 1L, confirmed_negative = 1L
  )
  for (name in names(engine_input$vcf_paths)) {
    table_name <- paste0("micro_", name)
    Rduckhts::rduckhts_bcf(
      con, table_name, engine_input$vcf_paths[[name]],
      scan_mode = "sequential", overwrite = TRUE
    )
    round_trip <- DBI::dbGetQuery(
      con, paste0("SELECT count(*) AS n FROM ", table_name)
    )
    expect_equal(round_trip$n, expected_rows[[name]])
  }
}
