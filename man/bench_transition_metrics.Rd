\name{bench_transition_metrics}
\alias{bench_transition_metrics}
\title{Score public transition predictions in SQL}
\usage{bench_transition_metrics(con, outcomes, predictions,
  task = c("resolved_direction", "observed_pathogenic_resolution"), threshold = 0.5)}
\arguments{
\item{con}{Caller-owned DuckDB DBI connection without an active transaction.}
\item{outcomes}{A public transition outcome relation.}
\item{predictions}{Relation with VARCHAR unit_id, condition_id, submitter_id, and numeric score. Context keys may be NULL.}
\item{task}{Resolved direction or observed pathogenic resolution.}
\item{threshold}{A finite probability in [0,1].}
}
\description{Compute counts, coverage, classification metrics, average precision, and ROC AUC without collecting the cohort.}
\details{Resolved direction uses only to_pathogenic and to_benign. Observed pathogenic resolution also includes still_vus and to_conflicting as no observed pathogenic resolution, not biological benign labels. Both tasks exclude missing, retired, changed-context, and other states. Missing predictions and NULL scores are abstentions. Scores must be finite probabilities. Ranking metrics operate on scored eligible rows. Average precision groups tied scores. Undefined rates return NULL. recall_eligible includes unscored eligible positives in its denominator.}
\value{A list with metrics (one row) and outcome_counts (all outcome states).}
