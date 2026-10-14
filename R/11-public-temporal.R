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
  if (!inherits(x, "POSIXct") || length(x) != 1L || is.na(x) || !is.finite(as.numeric(x))) {
    stop("A cutoff must be one POSIXct timestamp", call. = FALSE)
  }
  as.numeric(x)
}

.bench_public_snapshot <- function(con, relation, cutoff) {
  required <- c("unit_id", "condition_id", "submitter_id", "state", "available_at")
  schema <- .bench_relation_schema(con, relation)
  types <- stats::setNames(schema$column_type, schema$column_name)
  if (!all(required %in% names(types)) || any(types[required[1:4]] != "VARCHAR") ||
      !types[["available_at"]] %in% c("TIMESTAMP", "TIMESTAMP WITH TIME ZONE")) {
    stop("Source view must have the documented keys, state, and timestamp types", call. = FALSE)
  }
  bad <- DBI::dbGetQuery(con, glue::glue_sql(
    "SELECT 1 FROM {`relation`} WHERE unit_id IS NULL OR unit_id = ''
     OR available_at IS NULL OR NOT isfinite(available_at) LIMIT 1", .con = con))
  if (nrow(bad)) stop("Source identity and availability must be valid", call. = FALSE)
  # Each unit revision contains all contexts and declared fields at one availability time.
  selected <- glue::glue_sql(
    "SELECT source.*
     FROM {`relation`} AS source WHERE epoch(source.available_at) <= {cutoff}
     QUALIFY dense_rank() OVER (
       PARTITION BY source.unit_id ORDER BY epoch(source.available_at) DESC) = 1",
    .con = con)
  bad <- DBI::dbGetQuery(con, glue::glue_sql(
    "SELECT 1 FROM ({selected}) s WHERE state IS NULL
     OR state NOT IN ('vus','pathogenic','benign','conflict','retired','other') LIMIT 1", .con = con))
  if (nrow(bad)) stop("Invalid selected source state", call. = FALSE)
  duplicate <- DBI::dbGetQuery(con, glue::glue_sql(
    "SELECT 1 FROM ({selected}) s GROUP BY unit_id, condition_id, submitter_id
     HAVING count(*) > 1 LIMIT 1", .con = con))
  if (nrow(duplicate)) stop("Selected snapshot has duplicate unit/condition/submitter keys", call. = FALSE)
  selected
}

#' Build a public VUS transition cohort from dated source relations
#'
#' The source views have unit_id, condition_id, submitter_id, state, and
#' available_at. Keys are VARCHAR; condition and submitter may be NULL.
#' State is vus, pathogenic, benign, conflict, retired, or other.
#' Availability is TIMESTAMP (interpreted as UTC) or TIMESTAMPTZ, not an
#' assertion's evaluation date. Source adapters select one provider and grain.
#'
#' A view can contain one snapshot or retained unit history. Every unit revision
#' must include all its contexts at one available_at value. The latest eligible
#' revision supplies the complete unit state. Emit retired rows for withdrawals
#' in history; absence alone does not retire an earlier revision.
#' Map accession lineage explicitly before calling this function.
#'
#' Inputs retain every declared column from the selected before rows, with its
#' SQL type and value, including NULLs. No after columns or values are added to
#' inputs. The adapter must supply baseline-eligible features and provenance in
#' before; a row timestamp cannot establish the availability of an undated join.
#'
#' Later contexts remain in the later_contexts list column. A missing exact
#' context with surviving unit contexts is context_changed, not missing_later.
#' No later context is substituted as the old context's classification.
#' @param con Caller-owned DuckDB DBI connection without an active transaction.
#' @param before,after Names or DBI::Id values for source snapshots or unit histories.
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
  if (c1 <= c0) stop("t1 must be after t0", call. = FALSE)
  DBI::dbWithTransaction(con, {
    s0 <- .bench_public_snapshot(con, before, c0)
    s1 <- .bench_public_snapshot(con, after, c1)
    DBI::dbExecute(con, glue::glue_sql(
      "CREATE TABLE {`inputs`} AS SELECT * FROM ({s0}) b WHERE state = 'vus'", .con = con))
    DBI::dbExecute(con, glue::glue_sql(
      "CREATE TABLE {`outcomes`} AS
       WITH later AS ({s1}), contexts AS (
         SELECT unit_id, list(struct_pack(condition_id := condition_id,
           submitter_id := submitter_id, state := state, available_at := available_at)
           ORDER BY condition_id NULLS FIRST, submitter_id NULLS FIRST) AS later_contexts
         FROM later GROUP BY unit_id
       )
       SELECT b.unit_id, b.condition_id, b.submitter_id,
              b.state AS state_before, a.state AS state_after,
              CASE WHEN a.unit_id IS NULL AND c.unit_id IS NOT NULL THEN 'context_changed'
                WHEN a.unit_id IS NULL THEN 'missing_later'
                WHEN a.state = 'vus' THEN 'still_vus'
                WHEN a.state = 'pathogenic' THEN 'to_pathogenic'
                WHEN a.state = 'benign' THEN 'to_benign'
                WHEN a.state = 'conflict' THEN 'to_conflicting'
                WHEN a.state = 'retired' THEN 'retired' ELSE 'other' END AS outcome,
              c.later_contexts
       FROM {`inputs`} b LEFT JOIN later a
         ON b.unit_id = a.unit_id
        AND b.condition_id IS NOT DISTINCT FROM a.condition_id
        AND b.submitter_id IS NOT DISTINCT FROM a.submitter_id
       LEFT JOIN contexts c ON c.unit_id = b.unit_id", .con = con))
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
