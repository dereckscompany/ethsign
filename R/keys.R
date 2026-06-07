# File: R/keys.R
# Key and address utilities: private-key normalisation, address derivation, and
# random key generation.

#' Normalise a Private Key to `raw(32)`
#'
#' Accepts a `0x`-prefixed (or bare) 64-character hex string or a `raw(32)`
#' vector and returns the canonical `raw(32)` big-endian scalar.
#'
#' @param x A length-1 64-hex character string (optional `0x` prefix) or
#'   `raw(32)`.
#' @return `raw(32)`; the private scalar.
#' @importFrom rlang abort
#' @keywords internal
#' @noRd
normalise_private_key <- function(x) {
  if (is.raw(x)) {
    if (length(x) != 32L) {
      rlang::abort("`private_key` raw vector must be exactly 32 bytes.")
    }
    return(x)
  }
  if (is.character(x) && length(x) == 1L) {
    hex <- sub("^0[xX]", "", x)
    if (!grepl("^[0-9a-fA-F]{64}$", hex)) {
      rlang::abort(paste0(
        "`private_key` must be a 64-character hex string (optionally ",
        "0x-prefixed) or raw(32), e.g. ",
        "\"0x0123456789012345678901234567890123456789012345678901234567890123\"."
      ))
    }
    return(hex2raw(hex))
  }
  rlang::abort("`private_key` must be a length-1 hex string or raw(32).")
}

#' Derive an Ethereum Address from a Private Key
#'
#' Derives the secp256k1 public key and returns its Ethereum address: the
#' lowercase `0x`-prefixed last 20 bytes of `keccak256(pubkey_x || pubkey_y)`.
#'
#' @param private_key Character or raw; the signing key, a `0x`-prefixed 64-hex
#'   string or `raw(32)`.
#' @return Character; the lowercase `0x`-prefixed 20-byte address.
#'
#' @examples
#' eth_address("0x0123456789012345678901234567890123456789012345678901234567890123")
#'
#' @export
eth_address <- function(private_key) {
  priv32 <- normalise_private_key(private_key)
  return(eth_address_from_pubkey(pubkey_from_priv(priv32)))
}

#' Generate a New Random Ethereum Private Key
#'
#' Draws 32 cryptographically secure random bytes from [openssl::rand_bytes()]
#' and returns them as a `0x`-prefixed 64-hex string, rejecting the
#' (astronomically improbable) draws outside the valid secp256k1 scalar range
#' `(0, n)`.
#'
#' @return Character; a `0x`-prefixed 64-hex private key.
#'
#' @examples
#' priv <- eth_keygen()
#' eth_address(priv)
#'
#' @importFrom openssl rand_bytes
#' @export
eth_keygen <- function() {
  repeat {
    bytes <- openssl::rand_bytes(32L)
    d <- raw2bigz(bytes)
    if (d > 0 && d < secp256k1_n) {
      return(paste0("0x", raw2hex(bytes)))
    }
  }
}
