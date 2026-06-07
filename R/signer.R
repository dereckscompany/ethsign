# File: R/signer.R
# The public signer object: an R6 class holding the private key privately, with
# methods for the three signing paths (raw digest, EIP-712 typed data, EIP-191
# personal_sign), plus its constructors.

#' EthSigner: A Local Ethereum Wallet Signer
#'
#' Holds a secp256k1 private key privately and signs digests on its behalf. The
#' key is normalised to `raw(32)` at construction, never exposed by any public
#' member, and never printed. Construct one with [eth_signer()] (from an env var
#' or an explicit key) or [eth_signer_random()] (a throwaway key).
#'
#' All signing methods return an [eth_signature]; serialize it with [as_rsv()]
#' (the `{r, s, v}` object form, e.g. Hyperliquid) or [as_hex()] (the 65-byte
#' concatenated form, e.g. Polymarket).
#'
#' @section Signing paths:
#' - `$sign_digest(digest32)`: sign an arbitrary 32-byte digest directly.
#' - `$sign_typed_data(...)`: hash an EIP-712 struct via [eip712_digest()], then
#'   sign it.
#' - `$sign_message(text)`: EIP-191 `personal_sign` over
#'   `"\x19Ethereum Signed Message:\n" + nbytes + text` (covers SIWE / login).
#'
#' @importFrom R6 R6Class
#' @export
EthSigner <- R6::R6Class(
  "EthSigner",
  public = list(
    #' @description
    #' Initialise an EthSigner from a private key.
    #'
    #' @param private_key (scalar<character> | vector<raw, 32>) the signing key,
    #'   a `0x`-prefixed 64-hex string or `raw(32)`.
    #' @return (class<EthSigner>) invisible self.
    initialize = function(private_key) {
      assert_args_EthSigner__initialize(private_key)
      private$.priv <- normalise_private_key(private_key)
      private$.address <- eth_address_from_pubkey(pubkey_from_priv(private$.priv))
      return(invisible(assert_return_EthSigner__initialize(self)))
    },

    #' @description
    #' Sign a 32-byte digest directly (deterministic ECDSA, RFC 6979, low-s).
    #'
    #' @param digest32 (vector<raw, 32>) the digest to sign.
    #' @return (eth_signature) the signature.
    sign_digest = function(digest32) {
      assert_args_EthSigner__sign_digest(digest32)
      sig <- ecdsa_sign_rfc6979(digest32, private$.priv)
      return(assert_return_EthSigner__sign_digest(new_eth_signature(sig$r, sig$s, sig$v)))
    },

    #' @description
    #' Sign EIP-712 typed data: compute the typed-data digest via
    #' [eip712_digest()], then sign it.
    #'
    #' @param domain (list) the EIP-712 domain; see [eip712_digest()].
    #' @param primary_type (scalar<character>) the struct name.
    #' @param types (list) the ordered field list for `primary_type`.
    #' @param message (list) the named field values.
    #' @return (eth_signature) the signature.
    sign_typed_data = function(domain, primary_type, types, message) {
      assert_args_EthSigner__sign_typed_data(domain, primary_type, types, message)
      digest <- eip712_digest(domain, primary_type, types, message)
      return(assert_return_EthSigner__sign_typed_data(self$sign_digest(digest)))
    },

    #' @description
    #' EIP-191 `personal_sign`: keccak-256 of
    #' `"\x19Ethereum Signed Message:\n" + nbytes + text`, then sign. This is the
    #' digest used by Sign-In with Ethereum (SIWE) and most "sign this message to
    #' log in" flows.
    #'
    #' @param text (scalar<character>) the UTF-8 message to sign.
    #' @return (eth_signature) the signature.
    sign_message = function(text) {
      assert_args_EthSigner__sign_message(text)
      body <- charToRaw(enc2utf8(text))
      prefix <- c(
        as.raw(0x19),
        charToRaw("Ethereum Signed Message:\n"),
        charToRaw(as.character(length(body)))
      )
      return(assert_return_EthSigner__sign_message(self$sign_digest(keccak256(c(prefix, body)))))
    },

    #' @description
    #' Print the signer (its address only; the private key is never shown).
    #'
    #' @param ... Unused; for S3 compatibility.
    #' @return Invisibly self.
    print = function(...) {
      cat("<EthSigner>\n")
      cat("  address:", private$.address, "\n")
      return(invisible(self))
    }
  ),
  active = list(
    #' @field address (scalar<character>) read-only; the lowercase `0x`-prefixed
    #'   Ethereum address derived from the private key.
    address = function() {
      return(private$.address)
    }
  ),
  private = list(
    .priv = NULL,
    .address = NULL
  )
)

#' Create an EthSigner from a Private Key
#'
#' Returns an [EthSigner] for the given key. By default the key is read from the
#' `ETH_PRIVATE_KEY` environment variable so it never appears in code or
#' history; pass `private_key` explicitly to override.
#'
#' @param private_key (scalar<character> | vector<raw, 32>) the signing key, a
#'   `0x`-prefixed 64-hex string or `raw(32)`. Defaults to
#'   `Sys.getenv("ETH_PRIVATE_KEY")`.
#' @return (class<EthSigner>) the signer.
#'
#' @examples
#' signer <- eth_signer(
#'   "0x0123456789012345678901234567890123456789012345678901234567890123"
#' )
#' signer$address
#'
#' @importFrom rlang abort
#' @export
eth_signer <- function(private_key = Sys.getenv("ETH_PRIVATE_KEY")) {
  assert_args_eth_signer(private_key)
  if (is.character(private_key) && length(private_key) == 1L && !nzchar(private_key)) {
    rlang::abort(paste0(
      "No private key provided. Set the ETH_PRIVATE_KEY environment variable, ",
      "pass `private_key=` (a 0x-prefixed 64-hex string or raw(32)), or use ",
      "eth_signer_random() for a throwaway key."
    ))
  }
  return(assert_return_eth_signer(EthSigner$new(private_key)))
}

#' Create an EthSigner with a Fresh Random Key
#'
#' Convenience wrapper around [eth_keygen()] for tests and throwaway signers.
#'
#' @return (class<EthSigner>) a signer backed by a new random key.
#'
#' @examples
#' signer <- eth_signer_random()
#' signer$address
#'
#' @export
eth_signer_random <- function() {
  return(assert_return_eth_signer_random(EthSigner$new(eth_keygen())))
}
