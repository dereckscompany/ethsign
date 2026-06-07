# File: R/zzz.R
# Package load hook: the Keccak-256 self-test that guards the whole signing path.

#' Verify openssl Provides Original Keccak-256
#'
#' Fails fast if [openssl::keccak()] is not the original (pre-FIPS-202) Keccak
#' primitive, by checking the canonical empty-string Ethereum test vector. Rare
#' Linux openssl builds strip non-NIST primitives; this guard ensures a wrong
#' hashing primitive aborts at package load rather than silently producing
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
      "keccak256 self-test FAILED: openssl::keccak is not original Keccak-256 ",
      "(got ",
      got,
      ")."
    ))
  }
  return(invisible(TRUE))
}

#' Package Load Hook
#'
#' Runs the Keccak-256 self-test at load time so a system openssl that lacks the
#' original (pre-FIPS-202) Keccak primitive fails fast.
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
