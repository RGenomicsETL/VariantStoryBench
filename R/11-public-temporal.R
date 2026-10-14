.bench_relation_id <- function(x) {
  if (inherits(x, "Id")) return(x)
  if (is.character(x) && !is.object(x) && length(x) == 1L && !is.na(x) && nzchar(x)) return(x)
  stop("Use a table name or DBI::Id, not a SQL expression", call. = FALSE)
}

.bench_relation_schema <- function(con, x) {
  x <- .bench_relation_id(x)
  DBI::dbGetQuery(con, glue::glue_sql("DESCRIBE SELECT * FROM {`x`}", .con = con))[
    c("column_name", "column_type")]
}

.bench_cutoff <- function(x) {
  if (!inherits(x, "POSIXt") || length(x) != 1L || is.na(x) || !is.finite(as.numeric(x))) {
    stop("A cutoff must be one POSIXct timestamp", call. = FALSE)
  }
  format(x, "%Y-%m-%d %H:%M:%OS6+00:00", tz = "UTC")
}

#' Build a public VUS transition cohort from two selected source snapshots
#'
#' The source views have unit_id, condition_id, submitter_id, state, and
#' available_at. Keys are VARCHAR; condition and submitter may be NULL.
#' State is vus, pathogenic, benign, conflict, retired, or other.
#' Availability is TIMESTAMP (interpreted as UTC) or TIMESTAMPTZ, not an
#' assertion's evaluation date. Source adapters select one provider and grain.
#' Supply an explicit lineage mapping in those views when accessions change.
#' Neither this function nor the evaluator imports source data or infers truth.
#'
#' @param con Caller-owned DuckDB DBI connection without an active transaction.
#' @param before,after Names or DBI::Id values for selected source snapshots.
#' @param t0,t1 POSIXct cutoffs, with t1 after t0.
#' @param inputs,outcomes New output table names or DBI::Id values.
#' @return A list identifying the two published relations.
#' @export
bench_public_transitions <- function(con, before, after, t0, t1, inputs, outcomes) {
  before <- .bench_relation_id(before)
  after <- .bench_relation_id(after)
  inputs <- .bench_relation_id(inputs)
  outcomes <- .bench_relation_id(outcomes)
  c0 <- .bench_cutoff(t0)
  c1 <- .bench_cutoff(t1)
  if (t1 <= t0) stop("t1 must be after t0", call. = FALSE)
  required <- c("unit_id", "condition_id", "submitter_id", "state", "available_at")
  DBI::dbWithTransaction(con, {
    for (i in 1:2) {
      relation <- list(before, after)[[i]]
      cutoff <- c(c0, c1)[[i]]
      schema <- .bench_relation_schema(con, relation)
      types <- stats::setNames(schema$column_type, schema$column_name)
      if (!all(required %in% names(types)) ||
          any(types[required[1:4]] != "VARCHAR") ||
          !types[["available_at"]] %in% c("TIMESTAMP", "TIMESTAMP WITH TIME ZONE")) {
        stop("Source view must have the documented keys, state, and timestamp types", call. = FALSE)
      }
      bad <- DBI::dbGetQuery(con, glue::glue_sql(
        "SELECT 1 FROM {`relation`} WHERE unit_id IS NULL OR unit_id = ''
         OR state IS NULL OR state NOT IN ('vus','pathogenic','benign','conflict','retired','other')
         OR available_at IS NULL OR NOT isfinite(available_at)
         OR epoch(available_at) > epoch(CAST({cutoff} AS TIMESTAMPTZ)) LIMIT 1", .con = con))
      if (nrow(bad)) stop("Invalid state, identity, or post-cutoff source row", call. = FALSE)
      duplicate <- DBI::dbGetQuery(con, glue::glue_sql(
        "SELECT 1 FROM {`relation`} GROUP BY unit_id, condition_id, submitter_id HAVING count(*) > 1 LIMIT 1",
        .con = con))
      if (nrow(duplicate)) stop("Source snapshot has duplicate unit/condition/submitter keys", call. = FALSE)
    }
    DBI::dbExecute(con, glue::glue_sql(
      "CREATE TABLE {`inputs`} AS
       SELECT unit_id, condition_id, submitter_id, state, available_at
       FROM {`before`} WHERE state = 'vus'", .con = con))
    DBI::dbExecute(con, glue::glue_sql(
      "CREATE TABLE {`outcomes`} AS
       SELECT b.unit_id, b.condition_id, b.submitter_id,
              b.state AS state_before, a.state AS state_after,
              CASE WHEN a.unit_id IS NULL THEN 'missing_later'
                WHEN a.state = 'vus' THEN 'still_vus'
                WHEN a.state = 'pathogenic' THEN 'to_pathogenic'
                WHEN a.state = 'benign' THEN 'to_benign'
                WHEN a.state = 'conflict' THEN 'to_conflicting'
                WHEN a.state = 'retired' THEN 'retired' ELSE 'other' END AS outcome
       FROM {`inputs`} b LEFT JOIN {`after`} a
         ON b.unit_id = a.unit_id
        AND b.condition_id IS NOT DISTINCT FROM a.condition_id
        AND b.submitter_id IS NOT DISTINCT FROM a.submitter_id", .con = con))
  })
  list(inputs = inputs, outcomes = outcomes)
}

#' Compare complete result relations as multisets
#'
#' This compares every retained column, including duplicate rows and NULL values.
#' Row order is irrelevant. Volatile columns are ignored only when named explicitly.
#' @param con A caller-owned DuckDB DBI connection.
#' @param actual,expected Names or DBI::Id values for the result relations.
#' @param ignore Explicit column names to exclude from both relations.
#' @return Counts named actual_only and expected_only. Both zero means equality.
#' @export
bench_compare_relations <- function(con, actual, expected, ignore = character()) {
  actual <- .bench_relation_id(actual)
  expected <- .bench_relation_id(expected)
  if (!is.character(ignore) || anyNA(ignore)) stop("ignore must contain column names", call. = FALSE)
  a <- .bench_relation_schema(con, actual)
  b <- .bench_relation_schema(con, expected)
  if (!all(ignore %in% a$column_name) || !all(ignore %in% b$column_name)) {
    stop("An ignored column is absent", call. = FALSE)
  }
  a <- a[!a$column_name %in% ignore, , drop = FALSE]
  b <- b[!b$column_name %in% ignore, , drop = FALSE]
  a <- a[order(a$column_name), , drop = FALSE]
  b <- b[order(b$column_name), , drop = FALSE]
  rownames(a) <- rownames(b) <- NULL
  if (!nrow(a) || !identical(a, b)) stop("Compared columns and types must match", call. = FALSE)
  columns <- a$column_name
  DBI::dbGetQuery(con, glue::glue_sql(
    "SELECT 'actual_only' AS side, count(*)::DOUBLE AS n FROM (
       SELECT {`columns`*} FROM {`actual`} EXCEPT ALL SELECT {`columns`*} FROM {`expected`})
     UNION ALL
     SELECT 'expected_only', count(*)::DOUBLE FROM (
       SELECT {`columns`*} FROM {`expected`} EXCEPT ALL SELECT {`columns`*} FROM {`actual`})
     ORDER BY side", .con = con))
}
