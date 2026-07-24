library(targets)

tar_option_set(
  packages = "VariantStoryBench",
  format = "rds"
)

list(
  tar_target(
    cases,
    bench_read_manifest(
      system.file("extdata", "benchmark-cases.csv",
                  package = "VariantStoryBench"),
      "cases"
    )
  ),
  tar_target(
    truth,
    bench_read_manifest(
      system.file("extdata", "benchmark-truth.csv",
                  package = "VariantStoryBench"),
      "truth"
    )
  ),
  tar_target(
    runs,
    bench_read_manifest(
      system.file("extdata", "benchmark-runs.csv",
                  package = "VariantStoryBench"),
      "runs"
    )
  ),
  tar_target(
    evaluations,
    bench_read_manifest(
      system.file("extdata", "benchmark-evaluations.csv",
                  package = "VariantStoryBench"),
      "evaluations"
    )
  ),
  tar_target(
    candidates,
    bench_read_manifest(
      system.file("extdata", "benchmark-candidates.csv",
                  package = "VariantStoryBench"),
      "candidates"
    )
  ),
  tar_target(
    judgments,
    bench_read_manifest(
      system.file("extdata", "benchmark-judgments.csv",
                  package = "VariantStoryBench"),
      "judgments"
    )
  ),
  tar_target(
    judgment_sources,
    bench_read_manifest(
      system.file("extdata", "benchmark-judgment-sources.csv",
                  package = "VariantStoryBench"),
      "judgment_sources"
    )
  ),
  tar_target(
    benchmark_metrics,
    bench_rank_metrics(cases, truth, runs, evaluations, candidates)
  ),
  tar_target(
    grounding_metrics,
    bench_grounding_metrics(judgments, judgment_sources, candidates)
  )
)
