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
#' @param private_key (scalar<character> | vector<raw, 32>) the signing key, a
#'   `0x`-prefixed 64-hex string or `raw(32)`.
#' @return (scalar<character>) the lowercase `0x`-prefixed 20-byte address.
#'
#' @examples
#' eth_address("0x0123456789012345678901234567890123456789012345678901234567890123")
#'
#' @export
eth_address <- function(private_key) {
  assert_args_eth_address(private_key)
  priv32 <- normalise_private_key(private_key)
  return(assert_return_eth_address(eth_address_from_pubkey(pubkey_from_priv(priv32))))
}

#' Checksum-Encode an Ethereum Address (EIP-55)
#'
#' Mixed-case checksum encoding: starting from the lowercase hex address,
#' each hex digit that is a letter (`a`-`f`) is uppercased when the
#' corresponding nibble of `keccak256()` of the lowercase hex STRING (its
#' ASCII bytes, not the decoded address bytes) is `>= 8`. Wallets and block
#' explorers use this to catch a mistyped or truncated address before it is
#' used -- [eth_address()] and [eth_address_from_pubkey()] return the plain
#' lowercase form; this adds the checksum casing on top.
#'
#' @param address (scalar<character>) a `0x`-prefixed 40-hex Ethereum
#'   address, any case.
#' @return (scalar<character>) the `0x`-prefixed EIP-55 checksummed address.
#'
#' @examples
#' eth_checksum_address("0x5aaeb6053f3e94c9b9a09f33669435e7ef1beaed")
#'
#' @importFrom rlang abort
#' @export
eth_checksum_address <- function(address) {
  assert_args_eth_checksum_address(address)
  hex <- tolower(sub("^0[xX]", "", address))
  if (!grepl("^[0-9a-f]{40}$", hex)) {
    rlang::abort("eth_checksum_address(): `address` must be a 0x-prefixed 40-hex Ethereum address.")
  }
  hash_hex <- keccak256_hex(hex)
  addr_chars <- strsplit(hex, "")[[1]]
  hash_chars <- strsplit(hash_hex, "")[[1]]
  checksummed <- vapply(
    seq_along(addr_chars),
    function(i) {
      ch <- addr_chars[i]
      if (!grepl("[a-f]", ch)) {
        return(ch)
      }
      if (strtoi(hash_chars[i], 16L) >= 8L) {
        return(toupper(ch))
      }
      return(ch)
    },
    character(1)
  )
  return(assert_return_eth_checksum_address(paste0("0x", paste(checksummed, collapse = ""))))
}

#' Generate a New Random Ethereum Private Key
#'
#' Draws 32 cryptographically secure random bytes from [openssl::rand_bytes()]
#' and returns them as a `0x`-prefixed 64-hex string, rejecting the
#' (astronomically improbable) draws outside the valid secp256k1 scalar range
#' `(0, n)`.
#'
#' @return (scalar<character>) a `0x`-prefixed 64-hex private key.
#'
#' @examples
#' priv <- eth_keygen()
#' eth_address(priv)
#'
#' @importFrom openssl rand_bytes
#' @export
eth_keygen <- function() {
  key <- NULL
  repeat {
    bytes <- openssl::rand_bytes(32L)
    d <- raw2bigz(bytes)
    if (d > 0 && d < secp256k1_n) {
      key <- paste0("0x", raw2hex(bytes))
      break
    }
  }
  return(assert_return_eth_keygen(key))
}
