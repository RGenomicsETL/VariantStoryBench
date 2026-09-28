library(tinytest)

manifest_dir <- tempfile("bench-manifests-")
dir.create(manifest_dir)
expect_error(bench_manifest_paths(manifest_dir), "no CSV manifests")
writeLines("case_id", file.path(manifest_dir, "b.csv"))
writeLines("case_id", file.path(manifest_dir, "a.csv"))
writeLines("ignored", file.path(manifest_dir, "other.txt"))
expect_equal(
  bench_manifest_paths(manifest_dir),
  file.path(manifest_dir, c("a.csv", "b.csv"))
)
expect_error(bench_manifest_paths(file.path(manifest_dir, "missing")),
             "existing directory")
expect_error(bench_manifest_paths(NA_character_), "existing directory")
expect_true(length(bench_manifest_paths()) > 0L)
