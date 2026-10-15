if (requireNamespace("duckdb", quietly = TRUE)) {
check_clinvar_adapter <- function() {
  con <- DBI::dbConnect(duckdb::duckdb())
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE))
  DBI::dbExecute(con, "CREATE TABLE releases AS SELECT * FROM (VALUES
    ('r0',TIMESTAMP '2022-06-01'),('r1',TIMESTAMP '2026-07-01'),
    ('empty',TIMESTAMP '2026-08-01')) t(release_id,available_at)")
  DBI::dbExecute(con, "CREATE TABLE clinvar_policy_profiles AS SELECT * FROM (VALUES
    ('policy','default'),('policy','other')) t(policy_version,profile_id)")
  # These constructed rows test the provider schema. They are not study outcomes.
  DBI::dbExecute(con, "CREATE TABLE clinvar_policy_decisions AS SELECT * FROM (VALUES
    ('r0','policy','default','VCV1',18446744073709551615::UBIGINT,'d1','VUS',2,0.1::DECIMAL(6,3)),
    ('r0','policy','default','VCV1',18446744073709551615::UBIGINT,'d2','VUS',1,NULL::DECIMAL(6,3)),
    ('r0','policy','default','VCV2',2::UBIGINT,'d1','VUS',0,0.2::DECIMAL(6,3)),
    ('r1','policy','default','VCV1',18446744073709551615::UBIGINT,'d1','Pathogenic/Likely Pathogenic',3,0.9::DECIMAL(6,3)),
    ('r1','policy','default','VCV1',18446744073709551615::UBIGINT,'d2','Benign',2,0.8::DECIMAL(6,3)),
    ('r1','policy','other','VCV1',18446744073709551615::UBIGINT,'d1','Benign',1,0.0::DECIMAL(6,3)))
    t(release_id,policy_version,profile_id,vcv_accession,allele_id,disease_key,policy_classification,gold_stars,feature)")
  t0 <- as.POSIXct("2022-06-30", tz = "UTC")
  t1 <- as.POSIXct("2026-07-31", tz = "UTC")
  x <- bench_clinvar_arbitration_snapshot(con, "releases", t0, "before", "policy")
  expect_equal(x$release_id, "r0")
  expect_equal(x$profile_id, "default")
  bench_clinvar_arbitration_snapshot(con, "releases", t1, "after", "policy")
  expect_equal(DBI::dbGetQuery(con, "SELECT count(*)::INTEGER AS n FROM after")$n, 2L)
  expect_equal(DBI::dbGetQuery(con, "SELECT DISTINCT typeof(allele_id) AS t FROM before")$t, "UBIGINT")
  expect_equal(DBI::dbGetQuery(con, "SELECT DISTINCT typeof(feature) AS t FROM before")$t, "DECIMAL(6,3)")
  bench_public_transitions(con, "before", "after", t0, t1, "inputs", "outcomes")
  expect_equal(bench_compare_relations(con, "inputs", "before")$n, c(0,0))
  expect_equal(DBI::dbGetQuery(con, "SELECT outcome FROM outcomes ORDER BY unit_id,condition_id")$outcome,
               c("to_pathogenic", "to_benign", "missing_later"))
  expect_true(all(is.na(DBI::dbGetQuery(con, "SELECT submitter_id FROM inputs")$submitter_id)))
  expect_equal(DBI::dbGetQuery(con, "SELECT DISTINCT grain FROM inputs")$grain, "arbitration")
  expect_equal(DBI::dbGetQuery(con, "SELECT feature::VARCHAR AS f FROM inputs WHERE condition_id='d1' AND vcv_accession='VCV1'")$f,
               "0.100")
  DBI::dbExecute(con, "UPDATE clinvar_policy_decisions SET feature=0.7,policy_classification='Conflicting' WHERE release_id='r1'")
  bench_clinvar_arbitration_snapshot(con, "releases", t0, "before_again", "policy")
  expect_equal(bench_compare_relations(con, "before", "before_again")$n, c(0,0))
  bench_clinvar_arbitration_snapshot(con, "releases", t1+86400, "empty", "policy")
  expect_equal(DBI::dbGetQuery(con, "SELECT count(*)::INTEGER AS n FROM empty")$n, 0L)
  expect_error(bench_clinvar_arbitration_snapshot(con, "releases", t0, "bad", "unknown"), "existing provider")
  DBI::dbExecute(con, "INSERT INTO clinvar_policy_decisions SELECT * FROM clinvar_policy_decisions WHERE release_id='r0' LIMIT 1")
  expect_error(bench_clinvar_arbitration_snapshot(con, "releases", t0, "bad", "policy"), "unique source identities")
  expect_false(DBI::dbExistsTable(con, "bad"))
  DBI::dbExecute(con, "CREATE TABLE reserved AS SELECT *,0 AS unit_id FROM clinvar_policy_decisions WHERE false")
  expect_error(bench_clinvar_arbitration_snapshot(con, "releases", t0, "bad", "policy", decisions="reserved"), "conflict")
}
check_clinvar_adapter()
}
