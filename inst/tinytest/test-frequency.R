local({
rows <- 9L
observations <- data.frame(
  case_id = paste0("case-", c(1, 2, 2, 3, 4, 5, 6, 7, 8)),
  allele_id = paste0("allele-", c(1, 2, 2, 3, 4, 5, 6, 7, 8)),
  record_ordinal = c(1, 1, 1, 1, 1, 1, 1, 1, 1),
  alt_ordinal = rep(1, rows),
  normalization_method = rep("caller", rows),
  case_assembly = rep("GRCh38", rows),
  case_canonical_contig = rep("22", rows),
  case_position = seq_len(rows) + 100,
  case_reference = rep("A", rows),
  case_alternate = rep("C", rows),
  case_variant_key = c(1, 2, 2, 3, 4, 5, 6, 7, 8),
  case_is_hash = rep(FALSE, rows),
  case_identity_status = rep("supported", rows),
  shard_localized = c(TRUE, TRUE, TRUE, TRUE, FALSE, TRUE, TRUE, TRUE, TRUE),
  match_status = c(
    "matched", "provider_conflict", "provider_conflict",
    "absent_from_sites_vcf", "shard_not_localized", rep("matched", 4)
  ),
  provider_row_count = c(1, 2, 2, 0, 0, 1, 1, 1, 1),
  provider_id = c(rep("gnomAD", 3), NA, NA, rep("gnomAD", 4)),
  provider_release = c(rep("gnomAD genomes v4.1", 3), NA, NA,
                       rep("gnomAD genomes v4.1", 4)),
  provider_source_scope = c(rep("validation_fixture", 3), NA, NA,
                            rep("validation_fixture", 4)),
  source_contig = c(rep("chr22", 3), NA, NA, rep("chr22", 4)),
  source_record_ordinal = c(1, 2, 3, NA, NA, 4, 5, 6, 7),
  source_alt_ordinal = c(1, 1, 1, NA, NA, 1, 1, 1, 1),
  provider_row_id = c("chr22:1:1", "chr22:2:1", "chr22:3:1", NA, NA,
                      "chr22:4:1", "chr22:5:1", "chr22:6:1", "chr22:7:1"),
  provider_variant_id = c("rs1", "rs2", "rs3", NA, NA, "rs4", "rs5",
                          "rs6", "rs7"),
  source_filters = c("PASS", "PASS", "PASS", NA, NA, "PASS", "PASS",
                     "LowQual", NA),
  filter_status = c("pass", "pass", "pass", NA, NA, "pass", "pass",
                    "filtered", "missing"),
  observation_status = c(
    "observed", "observed", "observed", NA, NA,
    "not_observed_at_variant_site", "uncovered_at_variant_site",
    "filtered", "missing"
  ),
  global_ac = c(2, 3, 4, NA, NA, 0, 0, 5, NA),
  global_an = c(100, 100, 100, NA, NA, 100, 0, 100, NA),
  global_af = c(0.02, 0.03, 0.04, NA, NA, 0, NA, 0.05, NA),
  maximum_population = c("nfe", "afr", "amr", NA, NA, "nfe", "nfe",
                         "afr", NA),
  maximum_population_ac = c(1, 2, 2, NA, NA, 0, 0, 3, NA),
  maximum_population_an = c(50, 50, 50, NA, NA, 50, 0, 50, NA),
  maximum_population_af = c(0.02, 0.04, 0.04, NA, NA, 0, NA, 0.06, NA),
  filtering_allele_frequency_95 = c(0.01, 0.02, 0.03, NA, NA, 0, 0, 0.04, NA),
  filtering_allele_frequency_99 = c(0.02, 0.03, 0.04, NA, NA, 0, 0, 0.05, NA),
  stringsAsFactors = FALSE
)

expect_equal(bench_validate_frequency_observations(observations), observations)

fabricated_absence <- observations
fabricated_absence$provider_id[[4L]] <- "gnomAD"
expect_error(
  bench_validate_frequency_observations(fabricated_absence),
  "must not fabricate provider identity"
)
fabricated_zero <- observations
fabricated_zero$global_ac[[4L]] <- 0
expect_error(
  bench_validate_frequency_observations(fabricated_zero),
  "must not fabricate provider values"
)
wrong_zero <- observations
wrong_zero$global_ac[[6L]] <- 1
wrong_zero$global_af[[6L]] <- 0.01
expect_error(
  bench_validate_frequency_observations(wrong_zero),
  "status conflicts with AC/AN"
)
collapsed_conflict <- observations[-3L, ]
expect_error(
  bench_validate_frequency_observations(collapsed_conflict),
  "multiplicity"
)
duplicate_provider_row <- observations
duplicate_provider_row$provider_row_id[[3L]] <-
  duplicate_provider_row$provider_row_id[[2L]]
expect_error(
  bench_validate_frequency_observations(duplicate_provider_row),
  "distinct provider_row_id"
)
wrong_localization <- observations
wrong_localization$shard_localized[[5L]] <- TRUE
expect_error(
  bench_validate_frequency_observations(wrong_localization),
  "localization states conflict"
)
wrong_identity <- observations
wrong_identity$case_identity_status[[1L]] <- "unsupported_symbolic"
expect_error(
  bench_validate_frequency_observations(wrong_identity),
  "case identity status"
)
wrong_af <- observations
wrong_af$global_af[[1L]] <- 0.2
expect_error(
  bench_validate_frequency_observations(wrong_af),
  "global_af"
)
})
