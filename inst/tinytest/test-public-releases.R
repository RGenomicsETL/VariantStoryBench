if (requireNamespace("duckdb", quietly = TRUE)) {
check_public_releases <- function() {
  con <- DBI::dbConnect(duckdb::duckdb(), config = list(
    autoload_known_extensions = "false", autoinstall_known_extensions = "false"))
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE))
  DBI::dbExecute(con, "CREATE TABLE releases AS SELECT * FROM (VALUES
    ('r0',TIMESTAMP '2022-06-01'),('r1',TIMESTAMP '2026-07-01'),
    ('empty',TIMESTAMP '2026-08-01')) t(release_id,available_at)")
  DBI::dbExecute(con, "CREATE TABLE facts AS SELECT * FROM (VALUES
    ('r0','removed',18446744073709551615::UBIGINT,0.125::DECIMAL(8,3),['old']),
    ('r0','kept',1::UBIGINT,NULL::DECIMAL(8,3),NULL::VARCHAR[]),
    ('r1','kept',1::UBIGINT,0.875::DECIMAL(8,3),['new']))
    t(release_id,unit_id,variant_key,feature,tags)")
  t0 <- as.POSIXct("2022-06-01", tz = "UTC")
  t1 <- as.POSIXct("2026-07-01", tz = "UTC")
  x <- bench_public_release_snapshot(con, "facts", "releases", t0, "old")
  expect_equal(x$release_id, "r0")
  DBI::dbExecute(con, "CREATE TABLE expected_old AS SELECT * FROM facts WHERE release_id='r0'")
  expect_equal(bench_compare_relations(con, "old", "expected_old")$n, c(0,0))
  expect_equal(DBI::dbGetQuery(con, "SELECT variant_key::VARCHAR AS k FROM old WHERE unit_id='removed'")$k,
               "18446744073709551615")
  quoted <- DBI::Id(table = "new snapshot")
  x <- bench_public_release_snapshot(con, "facts", "releases", t1, quoted)
  expect_equal(x$release_id, "r1")
  expect_equal(DBI::dbReadTable(con, quoted)$unit_id, "kept")
  x <- bench_public_release_snapshot(con, "facts", "releases", t1 + 40*86400, "empty")
  expect_equal(x$release_id, "empty")
  expect_equal(DBI::dbGetQuery(con, "SELECT count(*)::INTEGER AS n FROM empty")$n, 0L)
  expect_equal(.bench_relation_schema(con, "empty"), .bench_relation_schema(con, "facts"))
  expect_error(bench_public_release_snapshot(con, "facts", "releases", t0-1, "bad"), "No complete release")
  expect_false(DBI::dbExistsTable(con, "bad"))
  DBI::dbExecute(con, "INSERT INTO releases VALUES ('tie',TIMESTAMP '2026-07-01')")
  expect_error(bench_public_release_snapshot(con, "facts", "releases", t1, "bad"), "ambiguous")
  DBI::dbExecute(con, "DELETE FROM releases WHERE release_id='tie'")
  DBI::dbExecute(con, "INSERT INTO releases SELECT * FROM releases WHERE release_id='r0'")
  expect_error(bench_public_release_snapshot(con, "facts", "releases", t1, "bad"), "unique identities")
  DBI::dbExecute(con, "DELETE FROM releases WHERE release_id='r0'")
  DBI::dbExecute(con, "CREATE TABLE occupied AS SELECT 7 AS sentinel")
  expect_error(bench_public_release_snapshot(con, "facts", "releases", t1, "occupied"))
  expect_equal(DBI::dbGetQuery(con, "SELECT * FROM occupied")$sentinel, 7L)
}
check_public_releases()
}
