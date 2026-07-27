library(targets)

tar_option_set(
  packages = "VariantStoryBench",
  format = "rds"
)

list(
  tar_target(
    micro_bundle,
    bench_generate_micro_cohort("benchmark-output/micro-cohort")
  ),
  tar_target(micro_engine_input, micro_bundle$engine_input),
  tar_target(micro_evaluator_truth, micro_bundle$evaluator_truth),
  tar_target(
    micro_input_contract,
    VariantStoryBench:::bench_validate_engine_input(micro_engine_input)
  ),
  tar_target(
    micro_truth_contract,
    VariantStoryBench:::bench_validate_evaluator_truth(micro_evaluator_truth)
  ),
  tar_target(
    micro_hpo_truth_contract,
    bench_hpo_metrics(
      micro_evaluator_truth$documents,
      micro_evaluator_truth$hpo_observations,
      micro_evaluator_truth$hpo_observations
    )
  ),
  tar_target(
    micro_sequence_truth_contract,
    bench_sequence_metrics(
      micro_evaluator_truth$sequence_truth,
      micro_evaluator_truth$sequence_truth
    )
  ),
  tar_target(
    micro_cnv_truth_contract,
    bench_cnv_metrics(
      micro_evaluator_truth$cnv_truth,
      micro_evaluator_truth$cnv_truth
    )
  )
)
