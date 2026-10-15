.bench_provider_fields <- function(con, relation, required) {
  schema <- .bench_relation_schema(con, relation)
  types <- stats::setNames(schema$column_type, schema$column_name)
  if (!all(names(required) %in% names(types)) ||
      any(types[names(required)] != required)) {
    stop("Provider columns do not match the requested source contract", call. = FALSE)
  }
  types
}

.bench_release_selection <- function(con, source, releases, cutoff) {
  .bench_provider_fields(con, source, c(release_id = "VARCHAR"))
  types <- .bench_provider_fields(con, releases, c(release_id = "VARCHAR"))
  if (!"available_at" %in% names(types) ||
      !types[["available_at"]] %in% c("TIMESTAMP", "TIMESTAMP WITH TIME ZONE")) {
    stop("Release availability must be TIMESTAMP in UTC or TIMESTAMPTZ", call. = FALSE)
  }
  bad <- DBI::dbGetQuery(con, glue::glue_sql(
    "SELECT 1 FROM {`releases`} WHERE release_id IS NULL OR release_id=''
     OR available_at IS NULL OR NOT isfinite(available_at) LIMIT 1", .con = con))
  duplicate <- DBI::dbGetQuery(con, glue::glue_sql(
    "SELECT 1 FROM {`releases`} GROUP BY release_id HAVING count(*) > 1 LIMIT 1", .con = con))
  if (nrow(bad) || nrow(duplicate)) {
    stop("Complete releases need unique identities and finite availability", call. = FALSE)
  }
  selected <- DBI::dbGetQuery(con, glue::glue_sql(
    "SELECT release_id,epoch(available_at) AS availability
     FROM {`releases`} WHERE epoch(available_at) <= {cutoff}
     ORDER BY available_at DESC LIMIT 2", .con = con))
  if (!nrow(selected)) stop("No complete release is available by the cutoff", call. = FALSE)
  if (nrow(selected) > 1L && selected$availability[[1L]] == selected$availability[[2L]]) {
    stop("The latest eligible release has an ambiguous availability time", call. = FALSE)
  }
  release_id <- selected$release_id[[1L]]
  list(release_id = release_id, query = glue::glue_sql(
    "SELECT s.* FROM {`source`} s WHERE s.release_id={release_id}", .con = con))
}

#' Select one complete public release
#'
#' Select the latest complete release available at the inclusive cutoff.
#' Preserve every source column and SQL type. Do not fill absent units from
#' older releases. A declared complete release can contain no source rows.
#' @param con Caller-owned DuckDB DBI connection without an active transaction.
#' @param source Relation containing VARCHAR release_id and source fields.
#' @param releases One row per complete release with release_id and available_at.
#'   Scope this relation to one provider. Availability is public availability,
#'   not import time. Use UTC TIMESTAMP or TIMESTAMPTZ.
#' @param cutoff One POSIXct timestamp.
#' @param output New output table identifier.
#' @return A list containing output and the selected release_id.
#' @export
bench_public_release_snapshot <- function(con, source, releases, cutoff, output) {
  source <- .bench_relation_id(source)
  releases <- .bench_relation_id(releases)
  output <- .bench_relation_id(output)
  cutoff <- .bench_cutoff(cutoff)
  DBI::dbWithTransaction(con, {
    selected <- .bench_release_selection(con, source, releases, cutoff)
    query <- selected$query
    DBI::dbExecute(con, glue::glue_sql("CREATE TABLE {`output`} AS {query}", .con = con))
    list(output = output, release_id = selected$release_id)
  })
}

#' Adapt a complete ClinVarbitration disease release for public benchmarks
#'
#' Reuse clinvar_policy_decisions and clinvar_policy_profiles from
#' RClinVarbitration, or exported relations with those schemas. This adapter
#' does not import XML or run arbitration. It selects one existing policy/profile.
#'
#' The provider release catalogue records import time, not public availability.
#' Supply a separate scoped release/availability view from public release dates.
#' Keep the same policy/profile for a source-release experiment.
#'
#' unit_id encodes the VCV/allele pair without changing the source allele_id.
#' condition_id is disease_key; submitter_id is NULL because this is arbitration,
#' not an individual submission or NCBI's VCV/RCV aggregate.
#' All original decision columns remain present with their original SQL types.
#' @param con Caller-owned DuckDB DBI connection without an active transaction.
#' @param releases Complete public releases with release_id and available_at.
#' @param cutoff One POSIXct timestamp.
#' @param output New output table identifier.
#' @param policy_version,profile_id Exact existing arbitration configuration.
#' @param decisions Provider disease-decision relation.
#' @param profiles Provider policy/profile relation.
#' @return A list with output, release_id, policy_version, and profile_id.
#' @export
bench_clinvar_arbitration_snapshot <- function(con, releases, cutoff, output,
  policy_version, profile_id = "default", decisions = "clinvar_policy_decisions",
  profiles = "clinvar_policy_profiles") {
  releases <- .bench_relation_id(releases)
  decisions <- .bench_relation_id(decisions)
  profiles <- .bench_relation_id(profiles)
  output <- .bench_relation_id(output)
  cutoff <- .bench_cutoff(cutoff)
  for (value in list(policy_version, profile_id)) {
    if (!is.character(value) || length(value) != 1L || is.na(value) || !nzchar(value)) {
      stop("Select explicit nonempty policy and profile identifiers", call. = FALSE)
    }
  }
  DBI::dbWithTransaction(con, {
    types <- .bench_provider_fields(con, decisions,
      c(release_id = "VARCHAR", policy_version = "VARCHAR", profile_id = "VARCHAR",
        vcv_accession = "VARCHAR", disease_key = "VARCHAR", policy_classification = "VARCHAR"))
    integer_types <- c("TINYINT", "SMALLINT", "INTEGER", "BIGINT", "HUGEINT",
      "UTINYINT", "USMALLINT", "UINTEGER", "UBIGINT", "UHUGEINT", "VARCHAR")
    if (!"allele_id" %in% names(types) || !types[["allele_id"]] %in% integer_types) {
      stop("Provider allele_id must use an exact integer or VARCHAR type", call. = FALSE)
    }
    reserved <- c("unit_id", "condition_id", "submitter_id", "state", "available_at", "provider", "grain")
    folded <- chartr("ABCDEFGHIJKLMNOPQRSTUVWXYZ", "abcdefghijklmnopqrstuvwxyz", names(types))
    if (any(folded %in% reserved)) stop("Decision columns conflict with benchmark adapter columns", call. = FALSE)
    .bench_provider_fields(con, profiles, c(policy_version = "VARCHAR", profile_id = "VARCHAR"))
    profile <- DBI::dbGetQuery(con, glue::glue_sql(
      "SELECT 1 FROM {`profiles`} WHERE policy_version={policy_version} AND profile_id={profile_id}", .con = con))
    if (nrow(profile) != 1L) stop("Select one existing provider policy/profile", call. = FALSE)
    selected <- .bench_release_selection(con, decisions, releases, cutoff)
    release_id <- selected$release_id
    rows <- glue::glue_sql(
      "SELECT d.* FROM {`decisions`} d WHERE d.release_id={release_id}
       AND d.policy_version={policy_version} AND d.profile_id={profile_id}", .con = con)
    bad <- DBI::dbGetQuery(con, glue::glue_sql(
      "SELECT 1 FROM ({rows}) d WHERE vcv_accession IS NULL OR vcv_accession=''
       OR allele_id IS NULL OR allele_id::VARCHAR='' LIMIT 1", .con = con))
    duplicate <- DBI::dbGetQuery(con, glue::glue_sql(
      "SELECT 1 FROM ({rows}) d GROUP BY vcv_accession,allele_id,disease_key
       HAVING count(*) > 1 LIMIT 1", .con = con))
    if (nrow(bad) || nrow(duplicate)) stop("Provider disease decisions need exact unique source identities", call. = FALSE)
    # Frame both components so delimiters inside an identifier cannot collide.
    DBI::dbExecute(con, glue::glue_sql(
      "CREATE TABLE {`output`} AS SELECT
       length(d.vcv_accession)::VARCHAR || ':' || d.vcv_accession ||
       length(d.allele_id::VARCHAR)::VARCHAR || ':' || d.allele_id::VARCHAR AS unit_id,
       d.disease_key AS condition_id,NULL::VARCHAR AS submitter_id,
       CASE d.policy_classification WHEN 'VUS' THEN 'vus'
         WHEN 'Pathogenic/Likely Pathogenic' THEN 'pathogenic'
         WHEN 'Benign' THEN 'benign' WHEN 'Conflicting' THEN 'conflict'
         ELSE 'other' END AS state,
       r.available_at,'RClinVarbitration' AS provider,'arbitration' AS grain,d.*
       FROM ({rows}) d JOIN {`releases`} r ON r.release_id=d.release_id", .con = con))
    list(output = output, release_id = release_id, policy_version = policy_version, profile_id = profile_id)
  })
}
