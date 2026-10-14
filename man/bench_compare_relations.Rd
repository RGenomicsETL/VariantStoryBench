\name{bench_compare_relations}
\alias{bench_compare_relations}
\title{Compare complete result relations}
\usage{bench_compare_relations(con, actual, expected, ignore = character())}
\arguments{
\item{con}{Caller-owned DuckDB DBI connection.}
\item{actual, expected}{Table names or DBI identifiers.}
\item{ignore}{Explicit volatile columns to omit from both sides.}
}
\description{Compare all retained columns using EXCEPT ALL in both directions. Duplicate multiplicity and NULL values are preserved.}
\value{A data frame with side and n. Both counts zero means multiset equality.}
