# File: R/signature.R
# The canonical signature object and its serializers. An `eth_signature` is an
# S3 list(r = <0x-hex>, s = <0x-hex>, v = <int 27|28>) with r/s stored as full
# 32-byte zero-padded hex (the lossless canonical form); the serializers project
# it onto the two venue wire formats.

#' Construct an `eth_signature`
#'
#' Builds the canonical signature object from the `(r, s, v)` triple produced by
#' [ecdsa_sign_rfc6979()]. `r`/`s` are stored as `0x`-prefixed 32-byte
#' zero-padded hex so both serializers ([as_rsv()], [as_hex()]) derive cleanly.
#'
#' @param r,s Signature scalars; a `gmp::bigz`, integer, hex string, or
#'   `raw(32)`.
#' @param v Integer; the recovery byte, `27` or `28`.
#' @return An S3 object of class `eth_signature`.
#' @keywords internal
#' @noRd
new_eth_signature <- function(r, s, v) {
  out <- list(
    r = paste0("0x", raw2hex(bigz2raw32(as_scalar_bigz(r)))),
    s = paste0("0x", raw2hex(bigz2raw32(as_scalar_bigz(s)))),
    v = as.integer(v)
  )
  class(out) <- "eth_signature"
  return(out)
}

#' Assert an Object is an `eth_signature`
#' @param sig The object to check.
#' @param what Character; the calling function name for the error message.
#' @return Invisibly `TRUE`; aborts otherwise.
#' @importFrom rlang abort
#' @keywords internal
#' @noRd
assert_eth_signature <- function(sig, what) {
  if (!inherits(sig, "eth_signature")) {
    rlang::abort(paste0(
      what,
      "(): `sig` must be an <eth_signature>, e.g. from ",
      "eth_signer(...)$sign_digest(digest)."
    ))
  }
  return(invisible(TRUE))
}

#' Project an `eth_signature` to its `{r, s, v}` Object Form
#'
#' Returns the signature as a `list(r, s, v)` with `r`/`s` as minimal `0x`-hex
#' (leading zeros stripped, matching `eth_utils.to_hex`). This is the form
#' venues such as Hyperliquid expect in the request body.
#'
#' @param sig An `eth_signature` from an [EthSigner].
#' @return A `list(r = <0x-hex>, s = <0x-hex>, v = <integer>)`.
#'
#' @examples
#' sig <- eth_signer_random()$sign_message("gm")
#' as_rsv(sig)
#'
#' @export
as_rsv <- function(sig) {
  assert_eth_signature(sig, "as_rsv")
  return(list(
    r = hex_minimal(sig$r),
    s = hex_minimal(sig$s),
    v = sig$v
  ))
}

#' Serialize an `eth_signature` to a 65-Byte Hex String
#'
#' Returns `0x` + 130 hex characters: `r(32) || s(32) || v(1)`, with `v` as
#' `27`/`28`. This is the concatenated form venues such as Polymarket expect.
#'
#' @param sig (eth_signature) a signature from an [EthSigner].
#' @return (scalar<character>) a `0x`-prefixed 130-hex-character signature.
#'
#' @examples
#' sig <- eth_signer_random()$sign_message("gm")
#' as_hex(sig)
#'
#' @export
as_hex <- function(sig) {
  assert_eth_signature(sig, "as_hex")
  r <- sub("^0[xX]", "", sig$r)
  s <- sub("^0[xX]", "", sig$s)
  return(paste0("0x", r, s, sprintf("%02x", sig$v)))
}

#' Strip Leading Zeros from a `0x`-Hex String
#' @param h Character; a `0x`-prefixed hex string.
#' @return Character; minimal `0x`-prefixed hex (`"0x0"` for zero).
#' @keywords internal
#' @noRd
hex_minimal <- function(h) {
  b <- sub("^0[xX]", "", h)
  b <- sub("^0+", "", b)
  if (b == "") {
    b <- "0"
  }
  return(paste0("0x", b))
}

#' Print an `eth_signature`
#'
#' @param x (eth_signature) the signature to print.
#' @param ... Unused; for S3 compatibility.
#' @return Invisibly `x`.
#' @export
print.eth_signature <- function(x, ...) {
  cat("<eth_signature>\n")
  cat("  r:", x$r, "\n")
  cat("  s:", x$s, "\n")
  cat("  v:", x$v, "\n")
  return(invisible(x))
}
