# File: R/zzz.R
# Package load hook: the Keccak-256 self-test that guards the whole signing path.

#' Verify Keccak-256 Produces the Canonical Ethereum Vector
#'
#' Fails fast if [keccak256()] does not return the original (pre-FIPS-202)
#' Keccak digest, by checking the canonical empty-string Ethereum test vector.
#' A cheap load-time guard against a wrong hashing primitive silently producing
#' invalid Ethereum signatures.
#'
#' @return Invisibly `TRUE`; aborts on mismatch.
#' @importFrom rlang abort
#' @keywords internal
#' @noRd
keccak256_self_test <- function() {
  got <- keccak256_hex("")
  want <- "c5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470"
  if (!identical(got, want)) {
    rlang::abort(paste0(
      "keccak256 self-test FAILED: not the original Keccak-256 (got ",
      got,
      ")."
    ))
  }
  return(invisible(TRUE))
}

#' Package Load Hook
#'
#' Runs the Keccak-256 self-test at load time so a wrong Keccak primitive fails
#' fast rather than silently producing invalid signatures.
#'
#' @param libname Character; the library directory (unused).
#' @param pkgname Character; the package name (unused).
#' @return Invisibly `NULL`; aborts on a Keccak mismatch.
#' @keywords internal
#' @noRd
.onLoad <- function(libname, pkgname) {
  keccak256_self_test()
  return(invisible(NULL))
}
