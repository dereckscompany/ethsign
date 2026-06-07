# File: R/types.R
# Reusable roxyassert @type shapes for the package's public contracts.

#' eth_signature: the canonical signature object
#'
#' An S3 object of class `eth_signature` holding the `(r, s, v)` triple as
#' `r`/`s` 0x-hex strings and an integer recovery byte `v`. Referenced by the
#' [EthSigner] signing methods and the [as_rsv()] / [as_hex()] serializers.
#'
#' @type eth_signature (class<eth_signature>)
#' @genassert
#' @exportassert
#' @name eth_signature
#' @keywords internal
NULL
