\name{bench_public_transitions}
\alias{bench_public_transitions}
\title{Build public dated VUS transitions}
\usage{
bench_public_transitions(con, before, after, t0, t1, inputs, outcomes)
}
\arguments{
\item{con}{Caller-owned DuckDB DBI connection without an active transaction.}
\item{before,after}{Source relation names or DBI::Id values.}
\item{t0,t1}{POSIXct cutoffs, with t1 after t0.}
\item{inputs,outcomes}{New output table identifiers.}
}
\description{Select the latest public unit revision at each cutoff. Publish separate baseline VUS inputs and later outcomes atomically.}
\details{Source columns are unit_id, condition_id, submitter_id, state, and available_at. Keys and state are VARCHAR. Condition and submitter may be NULL. States are vus, pathogenic, benign, conflict, retired, or other. Availability is TIMESTAMP in UTC or TIMESTAMPTZ.

History inputs contain the complete context set for each unit revision at one availability timestamp. Use explicit retired records for withdrawals. Map accession lineage upstream. Snapshots without older revisions are also supported.

Inputs retain every declared column from the selected before rows, in source order, with its SQL type and value, including NULLs. Empty inputs retain that schema. No after columns or values are added to inputs. The provider adapter must supply baseline-eligible features and provenance in before; a row timestamp cannot establish the availability of a feature joined from an undated source. Caller-supplied columns are not removed by name.

Exact context matches determine state_after. A surviving unit with a changed context produces context_changed, not missing_later. The later_contexts list retains the new condition, submitter, state, and availability rows. This function does not infer a diagnosis. UTC epoch comparisons do not require ICU string-to-timezone conversion.}
\value{A list identifying inputs and outcomes.}
