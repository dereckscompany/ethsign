# File: R/keccak.R
# Keccak-256 (original, pre-FIPS-202 Keccak as used by Ethereum) via secretbase.

#' Compute Keccak-256 of Raw Bytes or a UTF-8 String
#'
#' Ethereum uses the original Keccak (the pre-FIPS-202 padding scheme), NOT
#' SHA3-256. We hash with [secretbase::keccak()], which bundles its own Keccak
#' implementation and so is portable across systems regardless of the system
#' OpenSSL version. (`openssl::keccak()` depends on the system OpenSSL exposing
#' the legacy `keccak-256` algorithm, which only exists in OpenSSL >= 3.2 and is
#' absent on many systems.)
#'
#' @param x (raw | scalar<character>) raw bytes, or a length-1 character string
#'   (encoded as UTF-8 before hashing).
#' @return (vector<raw, 32>) a plain `raw(32)` digest.
#'
#' @examples
#' keccak256("") # the empty-string Ethereum vector
#' keccak256(as.raw(c(0x12, 0x34)))
#'
#' @importFrom secretbase keccak
#' @export
keccak256 <- function(x) {
  assert_args_keccak256(x)
  if (is.character(x)) {
    x <- charToRaw(enc2utf8(x))
  }
  return(assert_return_keccak256(secretbase::keccak(x, bits = 256L, convert = FALSE)))
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
