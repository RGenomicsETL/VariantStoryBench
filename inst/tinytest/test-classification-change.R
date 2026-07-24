library(tinytest)

decisions <- data.frame(
  release_id = c(
    rep("2022-06", 4), rep("2026-07", 5), rep("2026-07", 4)
  ),
  policy_receipt = c(
    rep("cpg-2.2.11/default", 9),
    rep("cpg-2.2.11/exclude-lab-x", 4)
  ),
  allele_id = c(
    "1", "2", "3", "4",
    "1", "2", "3", "5", "6",
    "1", "2", "3", "5"
  ),
  disease_key = c(
    "mondo:1", "mondo:2", "mondo:3", "mondo:4",
    "mondo:1", "mondo:2", "mondo:3", "mondo:5", "mondo:6",
    "mondo:1", "mondo:2", "mondo:3", "mondo:5"
  ),
  classification = c(
    "VUS", "VUS", "Pathogenic", "Likely Benign",
    "Pathogenic", "Benign", "VUS", "Likely Pathogenic", "VUS",
    "VUS", "Benign", "VUS", "Likely Pathogenic"
  ),
  gold_stars = c(1L, 1L, 2L, 1L, 2L, 1L, 1L, 1L, 0L, 1L, 1L, 1L, 1L),
  stringsAsFactors = FALSE
)

temporal <- bench_classification_diff(
  decisions,
  left_release = "2022-06",
  left_policy = "cpg-2.2.11/default",
  right_release = "2026-07",
  right_policy = "cpg-2.2.11/default"
)
expect_equal(nrow(temporal), 6L)
expect_equal(
  temporal$transition[temporal$allele_id == "1"],
  "resolved_pathogenic"
)
expect_equal(
  temporal$transition[temporal$allele_id == "2"],
  "resolved_benign"
)
expect_equal(
  temporal$transition[temporal$allele_id == "3"],
  "became_uncertain"
)
expect_equal(
  temporal$transition[temporal$allele_id == "4"],
  "removed"
)
expect_equal(
  temporal$transition[temporal$allele_id == "5"],
  "added"
)

policy <- bench_classification_diff(
  decisions,
  left_release = "2026-07",
  left_policy = "cpg-2.2.11/default",
  right_release = "2026-07",
  right_policy = "cpg-2.2.11/exclude-lab-x"
)
expect_equal(unique(policy$comparison_kind), "submitter_policy")
expect_equal(
  policy$transition[policy$allele_id == "1"],
  "became_uncertain"
)
expect_equal(
  policy$transition[policy$allele_id == "6"],
  "removed"
)

summary <- bench_classification_diff_summary(temporal)
expect_equal(sum(summary$decision_count), 6L)
expect_equal(unique(summary$total_decision_count), 6L)

expect_error(
  bench_classification_diff(
    decisions,
    "2022-06", "cpg-2.2.11/default",
    "2026-07", "cpg-2.2.11/exclude-lab-x"
  ),
  "not both"
)
