#' Execute a benchmark adapter
#'
#' @param adapter A [BenchAdapter].
#' @param input Existing input path.
#' @param output Destination path supplied to the adapter.
#' @param ... Reserved for adapter-specific options.
#' @return A [BenchCommandRun] for built-in command adapters.
#' @export
bench_execute <- S7::new_generic(
  "bench_execute",
  "adapter",
  function(adapter, input, output, ...) S7::S7_dispatch()
)

#' Contract for benchmark adapters
#'
#' The contract keeps implementations interchangeable without prescribing the
#' benchmark engine. Consumers can require `BenchRunner` before execution.
#'
#' @export
BenchRunner <- s7contract::new_interface(
  "BenchRunner",
  generics = list(
    bench_execute = s7contract::interface_requirement(
      bench_execute,
      args = list(
        input = S7::class_character,
        output = S7::class_character
      ),
      returns = BenchCommandRun
    )
  ),
  package = "VariantStoryBench"
)

bench_path <- function(path, name, must_exist = FALSE) {
  if (!is.character(path) || length(path) != 1L || is.na(path) || !nzchar(path)) {
    stop(name, " must be one non-empty path", call. = FALSE)
  }
  if (must_exist && !file.exists(path)) {
    stop(name, " does not exist: ", path, call. = FALSE)
  }
  normalizePath(path, winslash = "/", mustWork = must_exist)
}

bench_expand_arguments <- function(arguments, input, output) {
  arguments <- gsub("{input}", input, arguments, fixed = TRUE)
  gsub("{output}", output, arguments, fixed = TRUE)
}

bench_command_text <- function(executable, arguments) {
  paste(c(shQuote(executable), vapply(arguments, shQuote, character(1))), collapse = " ")
}

S7::method(bench_execute, BenchCommandAdapter) <- function(adapter, input, output, ...) {
  input <- bench_path(input, "input", must_exist = TRUE)
  output <- bench_path(output, "output")
  output_directory <- dirname(output)
  if (!dir.exists(output_directory)) {
    dir.create(output_directory, recursive = TRUE, showWarnings = FALSE)
  }
  if (!dir.exists(output_directory)) {
    stop("could not create output directory: ", output_directory, call. = FALSE)
  }

  arguments <- bench_expand_arguments(adapter@arguments, input, output)
  command <- do.call(
    exec,
    unname(c(list(adapter@executable), as.list(vapply(arguments, shQuote, character(1)))))
  )
  if (!is.null(adapter@working_directory)) {
    command <- cmd_wd(command, adapter@working_directory)
  }

  log <- paste0(output, ".log")
  status <- cmd_run(
    command,
    stdout = log,
    stderr = "2>&1",
    stdin = FALSE,
    verbose = FALSE
  )
  BenchCommandRun(
    command = bench_command_text(adapter@executable, arguments),
    status = as.integer(status),
    output = output,
    log = log
  )
}

#' Check a benchmark adapter contract
#'
#' @param adapter An adapter object.
#' @return `adapter`, invisibly.
#' @export
bench_assert_runner <- function(adapter) {
  s7contract::assert_implements(adapter, BenchRunner, arg = "adapter")
  invisible(adapter)
}
