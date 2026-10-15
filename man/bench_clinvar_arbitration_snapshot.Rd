\name{bench_clinvar_arbitration_snapshot}
\alias{bench_clinvar_arbitration_snapshot}
\title{Adapt a complete ClinVarbitration disease release}
\usage{bench_clinvar_arbitration_snapshot(con, releases, cutoff, output,
  policy_version, profile_id = "default", decisions = "clinvar_policy_decisions",
  profiles = "clinvar_policy_profiles")}
\arguments{
\item{con}{Caller-owned DuckDB DBI connection without an active transaction.}
\item{releases}{Complete public releases with release_id and available_at.}
\item{cutoff}{One POSIXct timestamp.}
\item{output}{New output table identifier.}
\item{policy_version,profile_id}{One exact existing arbitration configuration.}
\item{decisions}{RClinVarbitration disease decisions or an exported relation with the same required fields.}
\item{profiles}{Provider policy/profile relation.}
}
\description{Select one complete release and existing policy/profile, then add benchmark keys and states without discarding source fields. No XML import or arbitration runs here.}
\details{The provider catalogue records imported_at, not public availability. Supply a scoped public release-date relation. unit_id frames the VCV accession and allele ID; condition_id is disease_key and submitter_id is NULL. Original fields, types, and policy classifications remain. This is an arbitration task, not an SCV, RCV, or VCV aggregate task. Keep policy and profile fixed for a source-release comparison. Other source classification values map to other.}
\value{A list with output, release_id, policy_version, and profile_id.}
