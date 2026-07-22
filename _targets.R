library(targets)

tar_option_set(
  packages = "VariantStoryBench",
  format = "rds"
)

list(
  tar_target(
    manifest_paths,
    bench_manifest_paths(),
    format = "file"
  ),
  tar_target(
    manifest_results,
    lapply(manifest_paths, bench_read_results)
  ),
  tar_target(
    benchmark_metrics,
    do.call(rbind, lapply(manifest_results, bench_metrics))
  )
)
