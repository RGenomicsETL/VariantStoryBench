if (requireNamespace("duckdb", quietly = TRUE)) {
check_baseline_features <- function() {
  con <- DBI::dbConnect(duckdb::duckdb(), config = list(
    autoload_known_extensions = "false", autoinstall_known_extensions = "false"))
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE))
  DBI::dbExecute(con, "CREATE TABLE history AS SELECT *,
    'exact-allele'::VARCHAR AS allele_id,
    18446744073709551615::UBIGINT AS variant_key,
    CASE WHEN release='baseline' THEN NULL ELSE 9.0 END::DOUBLE AS nullable_feature,
    'public-provider'::VARCHAR AS provider,
    'criteria provided'::VARCHAR AS \"review status\", [true,NULL]::BOOLEAN[] AS flags
    FROM (VALUES
      ('shared','d1','s1','benign',TIMESTAMP '2022-01-01',0.1000::DECIMAL(10,4),'older',1),
      ('shared','d1','s2','benign',TIMESTAMP '2022-01-01',0.2000::DECIMAL(10,4),'older',1),
      ('shared','d1','s1','vus',TIMESTAMP '2022-06-30 12:00:00',0.2500::DECIMAL(10,4),'baseline',2),
      ('shared','d1','s2','vus',TIMESTAMP '2022-06-30 12:00:00',0.7500::DECIMAL(10,4),'baseline',2),
      ('shared','d1','s1','pathogenic',TIMESTAMP '2026-07-01',0.9900::DECIMAL(10,4),'future',3),
      ('shared','d1','s2','benign',TIMESTAMP '2026-07-01',0.8800::DECIMAL(10,4),'future',3),
      ('not-vus','d1','s1','vus',TIMESTAMP '2022-01-01',0.5000::DECIMAL(10,4),'older',1),
      ('not-vus','d1','s1','benign',TIMESTAMP '2022-06-30 12:00:00',0.6000::DECIMAL(10,4),'baseline',2),
      ('future-only','d1','s1','vus',TIMESTAMP '2027-01-01',1.0000::DECIMAL(10,4),'future',1)
    ) t(unit_id,condition_id,submitter_id,state,available_at,feature_score,release,accession_version)")
  DBI::dbExecute(con, "CREATE TABLE expected AS SELECT * FROM history
    WHERE unit_id='shared' AND available_at=TIMESTAMP '2022-06-30 12:00:00'")
  DBI::dbExecute(con, "CREATE TABLE later AS SELECT * EXCLUDE(state),
    CASE WHEN submitter_id='s1' THEN 'pathogenic' ELSE 'benign' END AS state,
    'later-only-value'::VARCHAR AS later_only_feature
    FROM expected")
  DBI::dbExecute(con, "UPDATE later SET available_at=TIMESTAMP '2026-07-01',
    feature_score=0.9900,nullable_feature=42,release='later-release',accession_version=99")
  DBI::dbExecute(con, "CREATE SCHEMA baseline_checks")
  input <- DBI::Id(schema = "baseline_checks", table = "input one")
  outcome <- DBI::Id(schema = "baseline_checks", table = "outcome one")
  t0 <- as.POSIXct("2022-06-30 12:00:00", tz = "UTC")
  t1 <- as.POSIXct("2026-07-31 12:00:00", tz = "UTC")
  bench_public_transitions(con, "history", "later", t0, t1, input, outcome)

  # The expected rows are specified independently of the as-of implementation.
  expect_identical(DBI::dbListFields(con, input), DBI::dbListFields(con, "expected"))
  input_schema <- DBI::dbGetQuery(con, glue::glue_sql(
    "DESCRIBE SELECT * FROM {`input`}", .con = con))[c("column_name", "column_type")]
  expected_schema <- DBI::dbGetQuery(con, "DESCRIBE SELECT * FROM expected")[c("column_name", "column_type")]
  expect_identical(input_schema, expected_schema)
  expect_equal(bench_compare_relations(con, input, "expected")$n, c(0,0))
  expect_equal(DBI::dbGetQuery(con, glue::glue_sql(
    "SELECT variant_key::VARCHAR AS key FROM {`input`} ORDER BY submitter_id", .con = con))$key,
    rep("18446744073709551615", 2))
  expect_true(all(DBI::dbGetQuery(con, glue::glue_sql(
    "SELECT nullable_feature IS NULL AS missing FROM {`input`}", .con = con))$missing))
  expect_false(any(c("later_only_feature", "state_after", "outcome", "later_contexts") %in%
    DBI::dbListFields(con, input)))

  # One unit/condition has two non-NULL submitters with divergent later states.
  states <- DBI::dbGetQuery(con, glue::glue_sql(
    "SELECT submitter_id,outcome FROM {`outcome`} ORDER BY submitter_id", .con = con))
  expect_equal(states$submitter_id, c("s1", "s2"))
  expect_equal(states$outcome, c("to_pathogenic", "to_benign"))
  expect_equal(DBI::dbGetQuery(con, glue::glue_sql(
    "SELECT len(later_contexts)::INTEGER AS n FROM {`outcome`} ORDER BY submitter_id", .con = con))$n,
    c(2L,2L))

  # Shared-history inputs must select complete baseline rows, not later features.
  bench_public_transitions(con, "history", "history", t0, t1, "shared_input", "shared_outcome")
  expect_equal(bench_compare_relations(con, "shared_input", "expected")$n, c(0,0))
  expect_equal(bench_compare_relations(con, "shared_outcome", outcome)$n, c(0,0))

  # Mutating later labels, same-name features, or later-only schema cannot change inputs.
  DBI::dbExecute(con, "UPDATE later SET state='conflict',feature_score=0.0100,
    nullable_feature=100,release='changed-later',later_only_feature='changed'")
  DBI::dbExecute(con, "ALTER TABLE later ADD COLUMN future_annotation VARCHAR DEFAULT 'future'")
  DBI::dbExecute(con, "UPDATE history SET feature_score=0.0100,nullable_feature=100,release='changed-future'
    WHERE available_at > TIMESTAMP '2022-06-30 12:00:00'")
  DBI::dbExecute(con, "INSERT INTO history SELECT * REPLACE(TIMESTAMP '2028-01-01' AS available_at)
    FROM expected")
  bench_public_transitions(con, "history", "later", t0, t1, "input_again", "outcome_again")
  expect_equal(bench_compare_relations(con, "input_again", "expected")$n, c(0,0))
  expect_identical(DBI::dbListFields(con, "input_again"), DBI::dbListFields(con, input))
  expect_false(any(c("later_only_feature", "future_annotation") %in% DBI::dbListFields(con, "input_again")))
  expect_equal(DBI::dbGetQuery(con, "SELECT outcome FROM outcome_again ORDER BY submitter_id")$outcome,
    c("to_conflicting", "to_conflicting"))
  expect_true(all(bench_compare_relations(con, "outcome_again", outcome)$n > 0))

  # Empty cohorts retain the declared baseline schema as well.
  bench_public_transitions(con, "history", "later", as.POSIXct("2021-01-01", tz = "UTC"),
    t1, "empty_input", "empty_outcome")
  empty_schema <- DBI::dbGetQuery(con, "DESCRIBE SELECT * FROM empty_input")[c("column_name", "column_type")]
  expect_identical(empty_schema, expected_schema)
  expect_equal(DBI::dbGetQuery(con, "SELECT count(*)::INTEGER AS n FROM empty_input")$n, 0L)
  expect_equal(DBI::dbGetQuery(con, "SELECT count(*)::INTEGER AS n FROM empty_outcome")$n, 0L)

  DBI::dbExecute(con, "CREATE TABLE occupied AS SELECT 1 AS sentinel")
  expect_error(bench_public_transitions(con, "history", "later", t0, t1, "rollback_input", "occupied"))
  expect_false(DBI::dbExistsTable(con, "rollback_input"))
  expect_equal(DBI::dbGetQuery(con, "SELECT sentinel FROM occupied")$sentinel, 1L)
}
check_baseline_features()
}
