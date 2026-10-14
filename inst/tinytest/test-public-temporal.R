if (requireNamespace("duckdb", quietly = TRUE)) {
con <- DBI::dbConnect(duckdb::duckdb())
DBI::dbExecute(con, "CREATE TABLE old AS SELECT * FROM (VALUES
 ('v1','d1',NULL::VARCHAR,'vus', TIMESTAMP '2022-06-01'),
 ('v1','d2',NULL::VARCHAR,'vus', TIMESTAMP '2022-06-01'),
 ('v2',NULL,NULL,'vus', TIMESTAMP '2022-06-01'),
 ('v3',NULL,NULL,'vus', TIMESTAMP '2022-06-01'),
 ('v4',NULL,NULL,'benign', TIMESTAMP '2022-06-01'))
 AS x(unit_id,condition_id,submitter_id,state,available_at)")
DBI::dbExecute(con, "CREATE TABLE new AS SELECT * FROM (VALUES
 ('v1','d1',NULL::VARCHAR,'pathogenic', TIMESTAMP '2026-07-01'),
 ('v1','d2',NULL::VARCHAR,'benign', TIMESTAMP '2026-07-01'),
 ('v2',NULL,NULL,'conflict', TIMESTAMP '2026-07-01'))
 AS x(unit_id,condition_id,submitter_id,state,available_at)")
t0 <- as.POSIXct("2022-06-30", tz = "UTC")
t1 <- as.POSIXct("2026-07-31", tz = "UTC")
relations <- bench_public_transitions(con, "old", "new", t0, t1, "inputs", "outcomes")
expect_equal(relations$inputs, "inputs")
out <- DBI::dbGetQuery(con, "SELECT outcome FROM outcomes ORDER BY unit_id, condition_id")
expect_equal(out$outcome, c("to_pathogenic", "to_benign", "to_conflicting", "missing_later"))
expect_true(!"state_after" %in% DBI::dbListFields(con, "inputs"))
expect_equal(DBI::dbGetQuery(con, "SELECT count(*)::INTEGER AS n FROM inputs")$n, 4L)
expect_error(bench_public_transitions(con, "old", "new", t1, t0, "x", "y"), "after t0")
bench_public_transitions(con, "old", "new", t0, t0 + 3600, "early_inputs", "early_outcomes")
expect_true(all(DBI::dbGetQuery(con, "SELECT outcome FROM early_outcomes")$outcome == "missing_later"))
DBI::dbExecute(con, "CREATE TABLE duplicate AS SELECT * FROM old UNION ALL SELECT * FROM old")
expect_error(bench_public_transitions(con, "duplicate", "new", t0, t1, "x", "y"), "duplicate")
expect_false(DBI::dbExistsTable(con, "x"))
DBI::dbExecute(con, "CREATE TABLE occupied AS SELECT 1 AS sentinel")
expect_error(bench_public_transitions(con, "old", "new", t0, t1, "rollback_inputs", "occupied"))
expect_false(DBI::dbExistsTable(con, "rollback_inputs"))
expect_equal(DBI::dbGetQuery(con, "SELECT * FROM occupied")$sentinel, 1L)
DBI::dbExecute(con, "CREATE TABLE empty AS SELECT * FROM old WHERE false")
bench_public_transitions(con, "empty", "new", t0, t1, "empty_input", "empty_output")
expect_equal(DBI::dbGetQuery(con, "SELECT count(*)::INTEGER AS n FROM empty_output")$n, 0L)
DBI::dbExecute(con, "CREATE TABLE result_a AS SELECT * FROM (VALUES (1,NULL::VARCHAR),(1,NULL),(2,'x')) t(id,value)")
DBI::dbExecute(con, "CREATE TABLE result_b AS SELECT value,id FROM result_a ORDER BY id DESC")
expect_equal(bench_compare_relations(con, "result_a", "result_b")$n, c(0,0))
DBI::dbExecute(con, "INSERT INTO result_b VALUES (NULL,1)")
expect_equal(bench_compare_relations(con, "result_a", "result_b")$n, c(0,1))
expect_error(bench_compare_relations(con, "result_a", "result_b", "absent"), "absent")
expect_error(bench_compare_relations(con, DBI::SQL("result_a"), "result_b"), "SQL expression")
DBI::dbDisconnect(con, shutdown = TRUE)
}
