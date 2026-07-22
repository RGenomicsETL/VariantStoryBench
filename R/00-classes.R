bench_scalar_character <- S7::new_property(
  S7::class_character,
  validator = function(value) {
    if (length(value) != 1L || is.na(value) || !nzchar(value)) {
      "must be one non-empty string"
    }
  }
)

bench_argument_vector <- S7::new_property(
  S7::class_character,
  validator = function(value) {
    if (anyNA(value)) "must not contain missing values"
  },
  default = character()
)

bench_optional_directory <- S7::new_property(
  S7::class_any,
  validator = function(value) {
    if (!is.null(value) &&
        (!is.character(value) || length(value) != 1L || is.na(value) || !nzchar(value))) {
      "must be NULL or one non-empty directory path"
    }
  },
  default = NULL
)

#' A benchmark command adapter
#'
#' `BenchAdapter` is an abstract S7 class. Concrete adapters expose a stable
#' execution contract through [bench_execute()].
#'
#' @export
BenchAdapter <- S7::new_class(
  "BenchAdapter",
  package = "VariantStoryBench",
  abstract = TRUE
)

#' A command-line benchmark adapter
#'
#' @param executable Command executable.
#' @param arguments Command arguments. `{input}` and `{output}` are replaced
#'   with the paths passed to [bench_execute()].
#' @param working_directory Optional command working directory.
#'
#' @export
BenchCommandAdapter <- S7::new_class(
  "BenchCommandAdapter",
  package = "VariantStoryBench",
  parent = BenchAdapter,
  properties = list(
    executable = bench_scalar_character,
    arguments = bench_argument_vector,
    working_directory = bench_optional_directory
  )
)

#' Receipt from a command adapter execution
#'
#' @param command Rendered executable and arguments.
#' @param status Process exit status.
#' @param output Requested output path.
#' @param log Combined standard-output and standard-error log path.
#'
#' @export
BenchCommandRun <- S7::new_class(
  "BenchCommandRun",
  package = "VariantStoryBench",
  properties = list(
    command = bench_scalar_character,
    status = S7::class_integer,
    output = bench_scalar_character,
    log = bench_scalar_character
  )
)
