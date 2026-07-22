library(tinytest)

input <- tempfile("variantstorybench-input-")
output <- tempfile("variantstorybench-output-")
writeLines("fixture", input)

adapter <- BenchCommandAdapter(
  executable = file.path(R.home("bin"), "Rscript"),
  arguments = c(
    "-e",
    "args <- commandArgs(trailingOnly = TRUE); file.copy(args[[1L]], args[[2L]], overwrite = TRUE)",
    "{input}",
    "{output}"
  )
)

expect_true(s7contract::implements(adapter, BenchRunner))
expect_true(invisible(bench_assert_runner(adapter)) |> S7::S7_inherits(BenchCommandAdapter))
run <- bench_execute(adapter, input, output)
expect_true(S7::S7_inherits(run, BenchCommandRun))
expect_equal(run@status, 0L)
expect_true(file.exists(run@output))
expect_equal(readLines(run@output), "fixture")
expect_true(file.exists(run@log))
