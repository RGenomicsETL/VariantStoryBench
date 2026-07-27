bench_path <- function(path, name, must_exist = FALSE) {
  if (!is.character(path) || length(path) != 1L || is.na(path) || !nzchar(path)) {
    stop(name, " must be one non-empty path", call. = FALSE)
  }
  if (must_exist && !file.exists(path)) {
    stop(name, " does not exist: ", path, call. = FALSE)
  }
  normalizePath(path, winslash = "/", mustWork = must_exist)
}

bench_required_columns <- function(x, required) {
  missing <- setdiff(required, names(x))
  if (length(missing)) {
    stop(
      "relation is missing required columns: ",
      paste(missing, collapse = ", "),
      call. = FALSE
    )
  }
}

bench_validate_half_open_spans <- function(start, end, name) {
  if (length(start) != length(end)) {
    stop(name, " span columns must have equal length", call. = FALSE)
  }
  start_missing <- is.na(start)
  end_missing <- is.na(end)
  if (any(xor(start_missing, end_missing))) {
    stop(
      name, " spans must provide both span_start and span_end or neither",
      call. = FALSE
    )
  }
  present <- !start_missing
  if (!any(present)) return(invisible(TRUE))
  if (!is.numeric(start) || !is.numeric(end) ||
      any(!is.finite(start[present]) | !is.finite(end[present]) |
          start[present] < 0 | start[present] != floor(start[present])) ||
      any(end[present] <= start[present] |
          end[present] != floor(end[present]))) {
    stop(
      name, " spans must be zero-based, half-open, strictly nonempty integer intervals",
      call. = FALSE
    )
  }
  invisible(TRUE)
}

#' List benchmark relation manifests
#'
#' @param path Directory containing CSV relation manifests.
#' @return Sorted CSV paths.
#' @export
bench_manifest_paths <- function(path = system.file("extdata", package = "VariantStoryBench")) {
  if (!is.character(path) || length(path) != 1L || is.na(path) || !dir.exists(path)) {
    stop("path must be an existing directory", call. = FALSE)
  }
  paths <- sort(list.files(path, pattern = "[.]csv$", full.names = TRUE))
  if (!length(paths)) stop("no CSV manifests found in: ", path, call. = FALSE)
  paths
}
