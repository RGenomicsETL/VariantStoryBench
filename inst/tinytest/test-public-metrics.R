if (requireNamespace("duckdb", quietly = TRUE)) {
con <- DBI::dbConnect(duckdb::duckdb())
DBI::dbExecute(con, "CREATE TABLE truth AS SELECT * FROM (VALUES
 ('p',NULL::VARCHAR,NULL::VARCHAR,'to_pathogenic'),
 ('b',NULL,NULL,'to_benign'),('u',NULL,NULL,'still_vus'),
 ('m',NULL,NULL,'missing_later'),('c',NULL,NULL,'context_changed'),
 ('a',NULL,NULL,'to_pathogenic')) t(unit_id,condition_id,submitter_id,outcome)")
DBI::dbExecute(con, "CREATE TABLE scores AS SELECT * FROM (VALUES
 ('p',NULL::VARCHAR,NULL::VARCHAR,0.9::DOUBLE),('b',NULL,NULL,0.1),('u',NULL,NULL,0.8))
 t(unit_id,condition_id,submitter_id,score)")
result <- bench_transition_metrics(con, "truth", "scores")
m <- result$metrics
expect_equal(m$cohort_n, 6)
expect_equal(m$eligible_n, 3)
expect_equal(m$excluded_n, 3)
expect_equal(m$scored_n, 2)
expect_equal(m$abstained_n, 1)
expect_equal(m$coverage, 2/3)
expect_equal(m$average_precision_scored, 1)
expect_equal(m$roc_auc_scored, 1)
expect_equal(m$balanced_accuracy_scored, 1)
expect_equal(m$recall_eligible, 0.5)
expect_equal(sum(result$outcome_counts$n), 6)
m <- bench_transition_metrics(con, "truth", "scores", "observed_pathogenic_resolution")$metrics
expect_equal(m$eligible_n, 4)
expect_equal(m$excluded_n, 2)
expect_equal(m$fp, 1)
expect_equal(m$balanced_accuracy_scored, 0.75)
DBI::dbExecute(con, "CREATE TABLE two AS SELECT * FROM truth WHERE unit_id IN ('p','b')")
DBI::dbExecute(con, "UPDATE scores SET score=0.5")
m <- bench_transition_metrics(con, "two", "scores")$metrics
expect_equal(m$average_precision_scored, 0.5)
expect_equal(m$roc_auc_scored, 0.5)
DBI::dbExecute(con, "CREATE TABLE empty_scores AS SELECT * FROM scores WHERE false")
m <- bench_transition_metrics(con, "truth", "empty_scores")$metrics
expect_equal(m$abstained_n, 3)
expect_equal(m$coverage, 0)
expect_true(is.na(m$average_precision_scored))
expect_true(is.na(m$roc_auc_scored))
DBI::dbExecute(con, "CREATE TABLE positive_only AS SELECT * FROM truth WHERE unit_id='p'")
m <- bench_transition_metrics(con, "positive_only", "scores")$metrics
expect_true(is.na(m$roc_auc_scored))
expect_true(is.na(m$balanced_accuracy_scored))
expect_error(bench_transition_metrics(con, "truth", "scores", threshold=NA_real_), "finite probability")
DBI::dbExecute(con, "UPDATE scores SET score=2 WHERE unit_id='p'")
expect_error(bench_transition_metrics(con, "truth", "scores"), "finite probabilities")
DBI::dbExecute(con, "UPDATE scores SET score=NULL WHERE unit_id='p'")
expect_equal(bench_transition_metrics(con, "truth", "scores")$metrics$abstained_n, 2)
DBI::dbExecute(con, "INSERT INTO scores SELECT * FROM scores WHERE unit_id='b'")
expect_error(bench_transition_metrics(con, "truth", "scores"), "valid and unique")
DBI::dbDisconnect(con, shutdown = TRUE)
}
