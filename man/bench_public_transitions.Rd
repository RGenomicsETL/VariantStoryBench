\name{bench_public_transitions}
\alias{bench_public_transitions}
\title{Build a public VUS transition cohort}
\usage{bench_public_transitions(con, before, after, t0, t1, inputs, outcomes)}
\arguments{
\item{con}{Caller-owned DuckDB DBI connection without an active transaction.}
\item{before, after}{Selected snapshot table names or DBI identifiers.}
\item{t0, t1}{POSIXct availability cutoffs; t1 must follow t0.}
\item{inputs, outcomes}{New output table names or DBI identifiers.}
}
\description{Select baseline VUS and join later outcomes at unit, condition, and submitter grain.}
\details{Source views contain VARCHAR unit_id, condition_id, submitter_id, state, and TIMESTAMP or TIMESTAMPTZ available_at. State is vus, pathogenic, benign, conflict, retired, or other. The provider maps its own classifications and accession lineage. NULL context keys match NULL. Later absence is missing_later, not benign. Inputs and outcomes publish atomically and must not already exist.}
\value{A list with inputs and outcomes relation identifiers.}
