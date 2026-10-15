\name{bench_public_release_snapshot}
\alias{bench_public_release_snapshot}
\title{Select one complete public release}
\usage{bench_public_release_snapshot(con, source, releases, cutoff, output)}
\arguments{
\item{con}{Caller-owned DuckDB DBI connection without an active transaction.}
\item{source}{Relation with VARCHAR release_id and source fields.}
\item{releases}{One row per complete release with release_id and available_at. Scope this relation to one provider. Use public availability as UTC TIMESTAMP or TIMESTAMPTZ.}
\item{cutoff}{One POSIXct timestamp.}
\item{output}{New output table identifier.}
}
\description{Select the latest complete release at an inclusive cutoff. Preserve all source columns and SQL types without filling absent units from older releases.}
\details{A complete release can contain no source rows. No eligible release and ambiguous latest availability are errors. Source import time and assertion evaluation dates do not establish public availability.}
\value{A list with output and release_id.}
