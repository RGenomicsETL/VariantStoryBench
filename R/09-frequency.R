#' Validate typed case-frequency observations
#'
#' Validates the engine-neutral population-frequency relation emitted from an
#' exact case/provider composition. Identity matching is kept separate from
#' provider filtering and observation status. Provider conflicts remain one row
#' per provider row; absent and unlocalized alleles retain one explicit
#' placeholder row and never become frequency zero.
#'
#' @param observations A data frame containing typed case, provider-row,
#'   matching, count, frequency, and filtering-allele-frequency fields.
#' @return `observations`, invisibly.
#' @export
bench_validate_frequency_observations <- function(observations) {
  if (!is.data.frame(observations) || !nrow(observations)) {
    stop("frequency observations must be a nonempty data frame", call. = FALSE)
  }
  required <- c(
    "case_id", "allele_id", "record_ordinal", "alt_ordinal",
    "normalization_method", "case_assembly", "case_canonical_contig",
    "case_position", "case_reference", "case_alternate", "case_variant_key",
    "case_is_hash", "case_identity_status", "shard_localized", "match_status",
    "provider_row_count", "provider_id", "provider_release",
    "provider_source_scope", "source_contig", "source_record_ordinal",
    "source_alt_ordinal", "provider_row_id", "provider_variant_id",
    "source_filters", "filter_status", "observation_status", "global_ac",
    "global_an", "global_af", "maximum_population", "maximum_population_ac",
    "maximum_population_an", "maximum_population_af",
    "filtering_allele_frequency_95", "filtering_allele_frequency_99"
  )
  bench_required_columns(observations, required)
  for (column in c(
    "case_id", "allele_id", "normalization_method", "case_assembly",
    "case_canonical_contig", "case_reference", "case_alternate",
    "case_identity_status", "match_status"
  )) {
    bench_nonempty_text(observations[[column]], paste0("observations$", column))
  }
  bench_choice_values(
    observations$normalization_method, c("caller", "duckhts"),
    "observations$normalization_method"
  )
  if (any(observations$case_assembly != "GRCh38")) {
    stop("frequency observations must use GRCh38 case identity", call. = FALSE)
  }
  bench_integer_values(observations$record_ordinal, "observations$record_ordinal", 1L)
  bench_integer_values(observations$alt_ordinal, "observations$alt_ordinal", 1L)
  bench_integer_values(observations$case_position, "observations$case_position", 1L)
  bench_integer_values(
    observations$provider_row_count, "observations$provider_row_count", 0L
  )
  if (!is.logical(observations$shard_localized) ||
      anyNA(observations$shard_localized) ||
      !is.logical(observations$case_is_hash)) {
    stop("shard_localized and case_is_hash must be logical", call. = FALSE)
  }
  bench_choice_values(
    observations$match_status,
    c(
      "unsupported_identity", "shard_not_localized", "absent_from_sites_vcf",
      "provider_conflict", "matched"
    ),
    "observations$match_status"
  )
  supported <- observations$case_identity_status == "supported"
  if (any(supported &
          (is.na(observations$case_variant_key) |
           is.na(observations$case_is_hash)))) {
    stop("supported case identity requires VariantKey and hash status",
         call. = FALSE)
  }

  provider_present <- observations$provider_row_count > 0L
  provider_text <- c(
    "provider_id", "provider_release", "provider_source_scope",
    "source_contig", "provider_row_id", "filter_status", "observation_status"
  )
  if (any(provider_present)) {
    for (column in provider_text) {
      bench_nonempty_text(
        observations[[column]][provider_present],
        paste0("provider rows$", column)
      )
    }
    bench_choice_values(
      observations$filter_status[provider_present],
      c("pass", "filtered", "missing"), "provider rows$filter_status"
    )
    bench_choice_values(
      observations$observation_status[provider_present],
      c(
        "observed", "not_observed_at_variant_site",
        "uncovered_at_variant_site", "filtered", "missing"
      ),
      "provider rows$observation_status"
    )
    for (column in c("source_record_ordinal", "source_alt_ordinal")) {
      bench_integer_values(
        observations[[column]][provider_present],
        paste0("provider rows$", column), 1L
      )
    }
  }
  provider_identity_columns <- c(
    "provider_id", "provider_release", "provider_source_scope",
    "source_contig", "source_record_ordinal", "source_alt_ordinal",
    "provider_row_id", "filter_status", "observation_status"
  )
  if (any(vapply(
    observations[provider_identity_columns],
    function(column) any(!is.na(column[!provider_present])), logical(1L)
  ))) {
    stop("zero-row matches must not fabricate provider identity", call. = FALSE)
  }
  provider_value_columns <- c(
    "provider_variant_id", "global_ac", "global_an", "global_af",
    "maximum_population", "maximum_population_ac", "maximum_population_an",
    "maximum_population_af", "filtering_allele_frequency_95",
    "filtering_allele_frequency_99"
  )
  if (any(vapply(
    observations[provider_value_columns],
    function(column) any(!is.na(column[!provider_present])), logical(1L)
  ))) {
    stop("zero-row matches must not fabricate provider values", call. = FALSE)
  }

  allele_key <- interaction(
    observations$case_id, observations$allele_id,
    drop = TRUE, lex.order = TRUE
  )
  groups <- split(seq_len(nrow(observations)), allele_key)
  for (indices in groups) {
    declared <- unique(observations$provider_row_count[indices])
    if (length(declared) != 1L ||
        length(indices) != max(1L, declared[[1L]])) {
      stop("provider row multiplicity must equal provider_row_count", call. = FALSE)
    }
    status <- unique(observations$match_status[indices])
    if (length(status) != 1L ||
        (status == "matched" && declared != 1L) ||
        (status == "provider_conflict" && declared <= 1L) ||
        (status %in% c(
          "unsupported_identity", "shard_not_localized",
          "absent_from_sites_vcf"
        ) && declared != 0L)) {
      stop("match status conflicts with provider row multiplicity", call. = FALSE)
    }
    if (declared > 0L && anyDuplicated(observations$provider_row_id[indices])) {
      stop("provider rows must retain distinct provider_row_id values",
           call. = FALSE)
    }
  }
  if (any(observations$match_status == "shard_not_localized" &
          observations$shard_localized) ||
      any(observations$match_status == "absent_from_sites_vcf" &
          !observations$shard_localized) ||
      any(provider_present & !observations$shard_localized)) {
    stop("match and shard localization states conflict", call. = FALSE)
  }
  if (any(
    (observations$match_status == "unsupported_identity") !=
      (observations$case_identity_status != "supported")
  )) {
    stop("match status conflicts with case identity status", call. = FALSE)
  }

  numeric_fields <- c(
    "global_ac", "global_an", "global_af", "maximum_population_ac",
    "maximum_population_an", "maximum_population_af",
    "filtering_allele_frequency_95", "filtering_allele_frequency_99"
  )
  for (column in numeric_fields) {
    bench_nonnegative_values(
      observations[[column]], paste0("observations$", column), missing = TRUE
    )
  }
  for (column in c(
    "global_ac", "global_an", "maximum_population_ac", "maximum_population_an"
  )) {
    values <- observations[[column]]
    if (any(values[!is.na(values)] != floor(values[!is.na(values)]))) {
      stop(column, " must contain integer counts", call. = FALSE)
    }
  }
  expected_global_af <- observations$global_ac / observations$global_an
  expected_global_af[is.na(expected_global_af) |
                     observations$global_an == 0] <- NA_real_
  if (!isTRUE(all.equal(
    observations$global_af, expected_global_af,
    tolerance = 1e-12, check.attributes = FALSE
  ))) {
    stop("global_af must equal global_ac / global_an", call. = FALSE)
  }
  expected_maximum_af <-
    observations$maximum_population_ac / observations$maximum_population_an
  expected_maximum_af[is.na(expected_maximum_af) |
                      observations$maximum_population_an == 0] <- NA_real_
  if (!isTRUE(all.equal(
    observations$maximum_population_af, expected_maximum_af,
    tolerance = 1e-12, check.attributes = FALSE
  ))) {
    stop(
      "maximum_population_af must equal maximum population AC / AN",
      call. = FALSE
    )
  }

  status <- observations$observation_status
  if (any(status %in% c(
        "observed", "not_observed_at_variant_site", "uncovered_at_variant_site"
      ) & observations$filter_status != "pass", na.rm = TRUE) ||
      any(status %in% "filtered" &
          observations$filter_status != "filtered", na.rm = TRUE)) {
    stop("provider observation status conflicts with filter status", call. = FALSE)
  }
  if (any(status %in% "observed" &
          (is.na(observations$global_ac) | observations$global_ac <= 0 |
           is.na(observations$global_an) | observations$global_an <= 0)) ||
      any(status %in% "not_observed_at_variant_site" &
          (is.na(observations$global_ac) | observations$global_ac != 0 |
           is.na(observations$global_an) | observations$global_an <= 0)) ||
      any(status %in% "uncovered_at_variant_site" &
          (is.na(observations$global_an) | observations$global_an != 0))) {
    stop("provider observation status conflicts with AC/AN", call. = FALSE)
  }
  invisible(observations)
}
