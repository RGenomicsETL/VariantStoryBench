.bench_metric_keys <- function(con, relation) {
  types <- .bench_relation_schema(con, relation)
  types <- stats::setNames(types$column_type, types$column_name)
  keys <- c("unit_id", "condition_id", "submitter_id")
  if (!all(keys %in% names(types)) || any(types[keys] != "VARCHAR")) {
    stop("Metric keys must be VARCHAR unit_id, condition_id, and submitter_id", call. = FALSE)
  }
  bad <- DBI::dbGetQuery(con, glue::glue_sql(
    "SELECT 1 FROM {`relation`} WHERE unit_id IS NULL OR unit_id='' LIMIT 1", .con = con))
  duplicate <- DBI::dbGetQuery(con, glue::glue_sql(
    "SELECT 1 FROM {`relation`} GROUP BY unit_id,condition_id,submitter_id HAVING count(*) > 1 LIMIT 1", .con = con))
  if (nrow(bad) || nrow(duplicate)) stop("Metric source keys must be valid and unique", call. = FALSE)
  types
}

#' Score public transition predictions without collecting the cohort
#'
#' Resolved direction compares to_pathogenic with to_benign only.
#' Observed pathogenic resolution retains every supplied baseline VUS.
#' Only to_pathogenic is positive; every other state means no observed pathogenic
#' resolution in this source comparison, not biological benignity.
#'
#' Missing predictions and NULL scores are abstentions. Ranking metrics use only
#' scored eligible units. Coverage and recall_eligible retain the full denominator.
#' Average precision uses whole tied-score groups, not arbitrary row order.
#' @param con Caller-owned DuckDB DBI connection without an active transaction.
#' @param outcomes Relation from bench_public_transitions().
#' @param predictions Relation with unit_id, condition_id, submitter_id, score.
#'   Scores are probabilities in [0,1], or NULL for abstention.
#' @param task Resolved direction or observed pathogenic resolution.
#' @param threshold Probability threshold for the positive prediction.
#' @return A list with metrics (one row) and outcome_counts (all public outcome states).
#' @export
bench_transition_metrics <- function(con, outcomes, predictions,
  task = c("resolved_direction", "observed_pathogenic_resolution"), threshold = 0.5) {
  outcomes <- .bench_relation_id(outcomes)
  predictions <- .bench_relation_id(predictions)
  task <- match.arg(task)
  if (!is.numeric(threshold) || length(threshold) != 1L || is.na(threshold) ||
      !is.finite(threshold) || threshold < 0 || threshold > 1) {
    stop("threshold must be one finite probability", call. = FALSE)
  }
  DBI::dbWithTransaction(con, {
    ot <- .bench_metric_keys(con, outcomes)
    pt <- .bench_metric_keys(con, predictions)
    if (!"outcome" %in% names(ot) || ot[["outcome"]] != "VARCHAR") {
      stop("Outcomes require a VARCHAR outcome column", call. = FALSE)
    }
    numeric_types <- c("TINYINT", "SMALLINT", "INTEGER", "BIGINT", "HUGEINT",
      "UTINYINT", "USMALLINT", "UINTEGER", "UBIGINT", "UHUGEINT", "FLOAT", "DOUBLE")
    if (!"score" %in% names(pt) ||
        !(pt[["score"]] %in% numeric_types || startsWith(pt[["score"]], "DECIMAL("))) {
      stop("Predictions require a numeric score column", call. = FALSE)
    }
    bad <- DBI::dbGetQuery(con, glue::glue_sql(
      "SELECT 1 FROM {`outcomes`} WHERE outcome IS NULL OR outcome NOT IN
       ('to_pathogenic','to_benign','still_vus','to_conflicting','missing_later','context_changed','retired','other') LIMIT 1", .con = con))
    if (nrow(bad)) stop("Unknown public outcome state", call. = FALSE)
    bad <- DBI::dbGetQuery(con, glue::glue_sql(
      "SELECT 1 FROM {`predictions`} WHERE score IS NOT NULL
       AND (NOT isfinite(score::DOUBLE) OR score < 0 OR score > 1) LIMIT 1", .con = con))
    if (nrow(bad)) stop("Scores must be finite probabilities or NULL", call. = FALSE)
    metrics <- DBI::dbGetQuery(con, glue::glue_sql(
      "WITH labels AS (
         SELECT unit_id,condition_id,submitter_id,outcome,
           CASE WHEN outcome='to_pathogenic' THEN 1
                WHEN outcome='to_benign' THEN 0
                WHEN {task}='observed_pathogenic_resolution' THEN 0
                ELSE NULL END AS label
         FROM {`outcomes`}
       ), joined AS (
         SELECT l.outcome,l.label,p.score::DOUBLE AS score
         FROM labels l LEFT JOIN {`predictions`} p ON l.unit_id=p.unit_id
           AND l.condition_id IS NOT DISTINCT FROM p.condition_id
           AND l.submitter_id IS NOT DISTINCT FROM p.submitter_id
       ), scored AS (
         SELECT label,score FROM joined WHERE label IS NOT NULL AND score IS NOT NULL
       ), bins AS (
         SELECT score,sum(label)::DOUBLE AS pos,(count(*)-sum(label))::DOUBLE AS neg
         FROM scored GROUP BY score
       ), curve AS (
         SELECT *,sum(pos) OVER (ORDER BY score DESC ROWS UNBOUNDED PRECEDING) AS tp,
                  sum(neg) OVER (ORDER BY score DESC ROWS UNBOUNDED PRECEDING) AS fp
         FROM bins
       ), totals AS (
         SELECT coalesce(sum(pos),0) AS positives,coalesce(sum(neg),0) AS negatives FROM bins
       ), ranking AS (
         SELECT sum((c.pos/nullif(t.positives,0))*(c.tp/nullif(c.tp+c.fp,0))) AS average_precision_scored,
           sum(c.pos*(t.negatives-c.fp+0.5*c.neg)/nullif(t.positives*t.negatives,0)) AS roc_auc_scored
         FROM curve c CROSS JOIN totals t
       ), counts AS (
         SELECT count(*)::DOUBLE AS cohort_n,
           count(*) FILTER(WHERE label IS NOT NULL)::DOUBLE AS eligible_n,
           count(*) FILTER(WHERE label=1)::DOUBLE AS eligible_positive_n,
           count(*) FILTER(WHERE label=0)::DOUBLE AS eligible_negative_n,
           count(*) FILTER(WHERE label IS NULL)::DOUBLE AS excluded_n,
           count(*) FILTER(WHERE label IS NOT NULL AND score IS NOT NULL)::DOUBLE AS scored_n,
           count(*) FILTER(WHERE label IS NOT NULL AND score IS NULL)::DOUBLE AS abstained_n
         FROM joined
       ), confusion AS (
         SELECT count(*) FILTER(WHERE label=1 AND score >= {threshold})::DOUBLE AS tp,
           count(*) FILTER(WHERE label=0 AND score >= {threshold})::DOUBLE AS fp,
           count(*) FILTER(WHERE label=0 AND score < {threshold})::DOUBLE AS tn,
           count(*) FILTER(WHERE label=1 AND score < {threshold})::DOUBLE AS fn,
           avg(pow(score-label,2)) AS brier_scored
         FROM scored
       )
       SELECT {task} AS task,{threshold}::DOUBLE AS threshold,counts.*,
         scored_n/nullif(eligible_n,0) AS coverage,
         confusion.tp,confusion.fp,confusion.tn,confusion.fn,
         tp/nullif(tp+fp,0) AS precision_scored,
         tp/nullif(tp+fn,0) AS recall_scored,
         tn/nullif(tn+fp,0) AS specificity_scored,
         0.5*(tp/nullif(tp+fn,0)+tn/nullif(tn+fp,0)) AS balanced_accuracy_scored,
         2*tp/nullif(2*tp+fp+fn,0) AS f1_scored,
         tp/nullif(eligible_positive_n,0) AS recall_eligible,
         confusion.brier_scored,ranking.*
       FROM counts CROSS JOIN confusion CROSS JOIN ranking", .con = con))
    counts <- DBI::dbGetQuery(con, glue::glue_sql(
      "SELECT outcome,count(*)::DOUBLE AS n FROM {`outcomes`} GROUP BY outcome ORDER BY outcome", .con = con))
    list(metrics = metrics, outcome_counts = counts)
  })
}
