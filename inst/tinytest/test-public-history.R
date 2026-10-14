if (requireNamespace("duckdb", quietly = TRUE)) {
con <- DBI::dbConnect(duckdb::duckdb(), config = list(autoload_known_extensions = "false", autoinstall_known_extensions = "false"))
DBI::dbExecute(con, "CREATE TABLE history AS SELECT * FROM (VALUES
 ('v1','d1','s1','benign', TIMESTAMP '2020-01-01'),
 ('v1','d1','s1','vus', TIMESTAMP '2022-01-01'),
 ('v1','d1','s1','pathogenic', TIMESTAMP '2026-01-01'),
 ('v1','d1','s1','benign', TIMESTAMP '2027-01-01'),
 ('ctx','old','s1','vus', TIMESTAMP '2022-01-01'),
 ('ctx','new','s2','benign', TIMESTAMP '2026-01-01'),
 ('multi','a',NULL::VARCHAR,'vus', TIMESTAMP '2022-01-01'),
 ('multi','b',NULL,'vus', TIMESTAMP '2022-01-01'),
 ('multi','a',NULL,'benign', TIMESTAMP '2026-01-01'),
 ('multi','b',NULL,'pathogenic', TIMESTAMP '2026-01-01'),
 ('gone',NULL,NULL,'vus', TIMESTAMP '2022-01-01'),
 ('gone',NULL,NULL,'retired', TIMESTAMP '2026-01-01'))
 AS t(unit_id,condition_id,submitter_id,state,available_at)")
t0 <- as.POSIXct("2022-06-30", tz = "UTC")
t1 <- as.POSIXct("2026-07-31", tz = "UTC")
bench_public_transitions(con, "history", "history", t0, t1, "input", "outcome")
expect_equal(DBI::dbGetQuery(con, "SELECT count(*)::INTEGER AS n FROM input")$n, 5L)
expect_equal(DBI::dbGetQuery(con, "SELECT state_after FROM outcome WHERE unit_id='v1'")$state_after, "pathogenic")
expect_equal(DBI::dbGetQuery(con, "SELECT outcome FROM outcome WHERE unit_id='ctx'")$outcome, "context_changed")
expect_true(is.na(DBI::dbGetQuery(con, "SELECT state_after FROM outcome WHERE unit_id='ctx'")$state_after))
contexts <- DBI::dbGetQuery(con, "SELECT c.condition_id AS condition_id,c.submitter_id AS submitter_id FROM
 (SELECT unnest(later_contexts) AS c FROM outcome WHERE unit_id='ctx')")
expect_equal(contexts$condition_id, "new")
expect_equal(contexts$submitter_id, "s2")
expect_equal(DBI::dbGetQuery(con, "SELECT outcome FROM outcome WHERE unit_id='multi' ORDER BY condition_id")$outcome,
             c("to_benign", "to_pathogenic"))
expect_equal(DBI::dbGetQuery(con, "SELECT outcome FROM outcome WHERE unit_id='gone'")$outcome, "retired")
DBI::dbExecute(con, "INSERT INTO history VALUES ('v1','d1','s1','conflict',TIMESTAMP '2028-01-01')")
bench_public_transitions(con, "history", "history", t0, t1, "input_again", "outcome_again")
expect_equal(bench_compare_relations(con, "input", "input_again")$n, c(0,0))
expect_equal(bench_compare_relations(con, "outcome", "outcome_again")$n, c(0,0))
expect_error(bench_public_transitions(con, "history", "history", NA_real_, t1, "bad", "bad_out"), "POSIXct")
DBI::dbDisconnect(con, shutdown = TRUE)
}
