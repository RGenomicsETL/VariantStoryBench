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
  c("affected", "affected", "unaffected", "unaffected", "affected")
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
  "micro-singleton", "micro-trio", "micro-xcnv"
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
leaky_input$case_manifest$causal_id <- "must-not-cross-boundary"
expect_error(
  VariantStoryBench:::bench_validate_engine_input(leaky_input),
  "cannot contain evaluator truth"
)
expect_equal(engine_input$generations$assembly, rep("GRCh38", 3L))
expect_equal(evaluator_truth$truth$causal_id, c(
  "1:100000:C:T", "2:199999:TG:T", "GRCh38:7:549996:559997:DEL"
))
expect_equal(unique(evaluator_truth$sequence_truth$record_id), c(
  "1:100000:C:T", "1:100100:T:G", "2:199999:TG:T", "2:200100:T:A",
  "2:200200:A:C", "2:200300:T:C", "GRCh38:7:549996:559997:DEL"
))
expect_equal(evaluator_truth$cnv_truth$contig, "7")
expect_equal(sort(unique(evaluator_truth$hpo_observations$context_status)), c(
  "absent/negated", "family_history", "present", "uncertain"
))
expect_equal(
  names(evaluator_truth$hpo_observations),
  ducksemantics::ducksemantics_hpo_observation_contract()
)
expect_false(any(c("case_id", "person_id") %in% names(
  evaluator_truth$hpo_observations
)))
expect_equal(
  evaluator_truth$documents$case_id[
    match(evaluator_truth$hpo_observations$document_id,
          evaluator_truth$documents$document_id)
  ],
  rep(c("micro-singleton", "micro-trio"), c(2L, 2L))
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
expect_equal(singleton$ref, c("C", "T"))
expect_equal(singleton$alt, c("T", "G"))
expect_equal(as.integer(singleton$GQ[, 1L]), c(99L, 78L))

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
expect_equal(hpo$term_truth_count, 4L)
expect_equal(hpo$context_truth_count, 4L)
expect_equal(hpo$span_truth_count, 4L)
expect_equal(hpo$term_recall, 1)
expect_equal(hpo$context_recall, 1)
expect_equal(hpo$span_recall, 1)

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

sequence <- bench_sequence_metrics(
  evaluator_truth$sequence_truth, evaluator_truth$sequence_truth
)
expect_equal(sequence$sequence_truth_count, 15L)
expect_equal(sequence$strict_sequence_correct_count, 15L)
expect_equal(sequence$quality_status_correct_count, 15L)
expect_equal(sequence$strict_sequence_accuracy, 1)
expect_equal(
  unname(as.integer(table(evaluator_truth$sequence_truth$case_id))),
  c(2L, 12L, 1L)
)
empty_sequence <- evaluator_truth$sequence_truth[FALSE, ]
empty_sequence_metrics <- bench_sequence_metrics(empty_sequence, empty_sequence)
expect_true(is.na(empty_sequence_metrics$strict_sequence_accuracy))
expect_false(is.nan(empty_sequence_metrics$strict_sequence_accuracy))

family <- bench_family_metrics(
  engine_input$relationships, evaluator_truth$inheritance_truth,
  engine_input$relationships, evaluator_truth$inheritance_truth
)
expect_equal(family$relationship_true_positive_count, 2L)
expect_equal(family$relationship_recall, 1)
expect_equal(family$inheritance_true_positive_count, 3L)
expect_equal(family$inheritance_recall, 1)

cnv <- bench_cnv_metrics(evaluator_truth$cnv_truth, evaluator_truth$cnv_truth)
expect_equal(cnv$cnv_interval_recall, 1)
expect_equal(cnv$cnv_authority_recall, 1)
wrong_authority <- evaluator_truth$cnv_truth
wrong_authority$authority_id <- "sequence_vcf"
wrong_cnv <- bench_cnv_metrics(evaluator_truth$cnv_truth, wrong_authority)
expect_equal(wrong_cnv$cnv_interval_recall, 1)
expect_equal(wrong_cnv$cnv_authority_recall, 0)
wrong_interval <- evaluator_truth$cnv_truth
wrong_interval$end <- wrong_interval$end - 1L
interval_cnv <- bench_cnv_metrics(evaluator_truth$cnv_truth, wrong_interval)
expect_equal(interval_cnv$cnv_interval_recall, 0)

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

if (requireNamespace("Rduckhts", quietly = TRUE) &&
    requireNamespace("DBI", quietly = TRUE)) {
  con <- Rduckhts::rduckhts_connect()
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  expected_rows <- c(singleton = 2L, trio = 4L, symbolic_cnv = 1L)
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
