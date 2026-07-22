#' VariantStoryBench: reproducible variant reanalysis benchmarks
#'
#' Tools for defining benchmark results, executing declared command adapters,
#' and calculating ranking metrics.
#'
#' @importFrom blit cmd_run cmd_wd exec
#' @keywords internal
"_PACKAGE"

.onLoad <- function(libname, pkgname) {
  S7::methods_register()
}
