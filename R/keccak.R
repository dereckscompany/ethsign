# File: R/keccak.R
# Keccak-256 (original, pre-FIPS-202 Keccak as used by Ethereum) via openssl.

#' Compute Keccak-256 of Raw Bytes or a UTF-8 String
#'
#' Ethereum uses the original Keccak (the pre-FIPS-202 padding scheme), NOT
#' SHA3-256. [openssl::keccak()] (openssl >= 2.3) implements original Keccak, so
#' it is the hashing primitive used throughout this package's signing path. A
#' load-time self-test (see `.onLoad()`) aborts if the system openssl ships a
#' FIPS-202 SHA3 under this name.
#'
#' @param x (raw | scalar<character>) raw bytes, or a length-1 character string
#'   (encoded as UTF-8 before hashing).
#' @return (vector<raw, 32>) a plain `raw(32)` digest (the `"hash"` class
#'   attribute is stripped).
#'
#' @examples
#' keccak256("") # the empty-string Ethereum vector
#' keccak256(as.raw(c(0x12, 0x34)))
#'
#' @importFrom openssl keccak
#' @export
keccak256 <- function(x) {
  assert_args_keccak256(x)
  if (is.character(x)) {
    x <- charToRaw(enc2utf8(x))
  }
  # c() strips the "hash" class attribute -> plain raw(32)
  return(assert_return_keccak256(c(openssl::keccak(x, size = 256))))
}

#' Keccak-256 as a Lowercase Hex String
#'
#' Convenience wrapper around [keccak256()] returning the digest as 64 lowercase
#' hex characters (no `0x` prefix).
#'
#' @param x A raw vector or a length-1 character string.
#' @return Character; the 64-character lowercase hex digest.
#' @keywords internal
#' @noRd
keccak256_hex <- function(x) {
  return(raw2hex(keccak256(x)))
}
