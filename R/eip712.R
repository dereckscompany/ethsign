# File: R/eip712.R
# Minimal EIP-712 structured-data hashing for the atomic field types EVM venues
# such as Hyperliquid and Polymarket use: string, uint64, uint256, bool,
# address, bytes32.
#
# Representation:
#   types   : unnamed list of list(name = <chr>, type = <chr>)  (ordered!)
#   message : named list, values looked up by field name

#' Encode an EIP-712 Type String
#'
#' Produces `"Primary(type1 name1,type2 name2,...)"`. Nested struct types are
#' out of scope for this v0 (single-struct) implementation.
#'
#' @param primary_type Character; the struct name.
#' @param fields Unnamed list of `list(name, type)` in definition order.
#' @return Character; the canonical type string.
#' @keywords internal
#' @noRd
eip712_encode_type <- function(primary_type, fields) {
  parts <- vapply(fields, function(f) paste(f$type, f$name), character(1))
  return(paste0(primary_type, "(", paste(parts, collapse = ","), ")"))
}

#' Keccak-256 of an EIP-712 Type String
#' @inheritParams eip712_encode_type
#' @return `raw(32)`; the type hash.
#' @keywords internal
#' @noRd
eip712_type_hash <- function(primary_type, fields) {
  return(keccak256(eip712_encode_type(primary_type, fields)))
}

#' Encode a Single EIP-712 Atomic Value to 32 Bytes
#'
#' Every supported atomic EIP-712 value encodes to exactly 32 bytes.
#'
#' @param type Character; one of `string`, `bytes32`, `uint64`, `uint256`,
#'   `bool`, `address`.
#' @param value The R value to encode.
#' @return `raw(32)`.
#' @importFrom gmp as.bigz
#' @importFrom rlang abort
#' @keywords internal
#' @noRd
eip712_encode_value <- function(type, value) {
  if (type == "string") {
    return(keccak256(as.character(value))) # hash of UTF-8 bytes
  }
  if (type == "bytes32") {
    if (!is.raw(value) || length(value) != 32) {
      rlang::abort("eip712: a `bytes32` value must be raw(32).")
    }
    return(value)
  }
  if (type %in% c("uint64", "uint256")) {
    # accept double (whole, < 2^53) or bigz; left-pad big-endian to 32
    if (is.numeric(value)) {
      value <- gmp::as.bigz(value)
    }
    return(bigz2raw32(value))
  }
  if (type == "bool") {
    out <- raw(32)
    if (isTRUE(value)) {
      out[32] <- as.raw(1)
    }
    return(out)
  }
  if (type == "address") {
    b <- hex2raw(value)
    if (length(b) != 20) {
      rlang::abort("eip712: an `address` value must be 20 bytes (a 0x-prefixed 40-hex string).")
    }
    return(c(raw(12), b)) # left-pad to 32
  }
  rlang::abort(paste0(
    "eip712: unsupported field type '", type, "'. Supported: string, bytes32, ",
    "uint64, uint256, bool, address."
  ))
}

#' Hash an EIP-712 Struct
#'
#' Computes `keccak(typeHash || enc(field1) || enc(field2) || ...)`. Fields are
#' encoded in TYPE-DEFINITION order; extra message keys are ignored, matching
#' eth_account's `encode_typed_data`.
#'
#' @param primary_type Character; the struct name.
#' @param fields Unnamed list of `list(name, type)` in definition order.
#' @param message Named list of field values.
#' @return `raw(32)`; the struct hash.
#' @importFrom rlang abort
#' @keywords internal
#' @noRd
eip712_hash_struct <- function(primary_type, fields, message) {
  data <- eip712_type_hash(primary_type, fields)
  for (f in fields) {
    if (!f$name %in% names(message)) {
      rlang::abort(paste0("eip712: message is missing field '", f$name, "'."))
    }
    data <- c(data, eip712_encode_value(f$type, message[[f$name]]))
  }
  return(keccak256(data))
}

EIP712_DOMAIN_FIELDS <- list(
  list(name = "name", type = "string"),
  list(name = "version", type = "string"),
  list(name = "chainId", type = "uint256"),
  list(name = "verifyingContract", type = "address")
)

#' Compute the EIP-712 Domain Separator
#' @param name,version Character; domain name and version.
#' @param chain_id Numeric or `gmp::bigz`; EIP-155 chain id.
#' @param verifying_contract Character; `0x`-prefixed 20-byte address.
#' @return `raw(32)`; the domain separator.
#' @keywords internal
#' @noRd
eip712_domain_separator <- function(name, version, chain_id, verifying_contract) {
  message <- list(
    name = name,
    version = version,
    chainId = chain_id,
    verifyingContract = verifying_contract
  )
  return(eip712_hash_struct("EIP712Domain", EIP712_DOMAIN_FIELDS, message))
}

#' Compute the Final EIP-712 Signing Digest
#'
#' `keccak(0x19 0x01 || domainSeparator || hashStruct(message))`.
#'
#' @param domain_separator `raw(32)`; from `eip712_domain_separator()`.
#' @param struct_hash `raw(32)`; from `eip712_hash_struct()`.
#' @return `raw(32)`; the digest to sign.
#' @keywords internal
#' @noRd
eip712_signing_digest <- function(domain_separator, struct_hash) {
  return(keccak256(c(as.raw(c(0x19, 0x01)), domain_separator, struct_hash)))
}

# ---- public entry point ------------------------------------------------------

#' Compute an EIP-712 Typed-Data Signing Digest
#'
#' Hashes a single EIP-712 struct under its domain and returns the
#' `0x1901`-prefixed digest ready to sign (the value an [EthSigner] passes to
#' `$sign_digest()`). This is the standard typed-data digest used by EVM venues
#' such as Hyperliquid and Polymarket.
#'
#' Scope: a single struct over atomic field types (`string`, `uint64`,
#' `uint256`, `bool`, `address`, `bytes32`). Nested struct types and arrays are
#' out of scope for v0.
#'
#' @param domain Named list; the EIP-712 domain, with `name` (character),
#'   `version` (character), `chainId` (numeric or `gmp::bigz`), and
#'   `verifyingContract` (a `0x`-prefixed 20-byte address).
#' @param primary_type Character; the struct name, e.g. `"Order"`.
#' @param types Unnamed list; the ordered field list for `primary_type`, each
#'   element a `list(name = <chr>, type = <chr>)` in definition order.
#' @param message Named list; field values, looked up by field name.
#' @return `raw(32)`; the signing digest.
#'
#' @examples
#' domain <- list(
#'   name = "Exchange",
#'   version = "1",
#'   chainId = 1337,
#'   verifyingContract = "0x0000000000000000000000000000000000000000"
#' )
#' types <- list(
#'   list(name = "source", type = "string"),
#'   list(name = "connectionId", type = "bytes32")
#' )
#' message <- list(source = "a", connectionId = keccak256("hello"))
#' eip712_digest(domain, "Agent", types, message)
#'
#' @importFrom rlang abort
#' @export
eip712_digest <- function(domain, primary_type, types, message) {
  required <- c("name", "version", "chainId", "verifyingContract")
  if (!is.list(domain) || !all(required %in% names(domain))) {
    rlang::abort(paste0(
      "eip712_digest(): `domain` must be a named list with name, version, ",
      "chainId, verifyingContract, e.g. ",
      "list(name = \"Exchange\", version = \"1\", chainId = 1337, ",
      "verifyingContract = \"0x0000000000000000000000000000000000000000\")."
    ))
  }
  if (!is.character(primary_type) || length(primary_type) != 1L) {
    rlang::abort("eip712_digest(): `primary_type` must be a length-1 character string, e.g. \"Order\".")
  }
  if (!is.list(types) || length(types) == 0L) {
    rlang::abort(paste0(
      "eip712_digest(): `types` must be a non-empty unnamed list of ",
      "list(name=, type=), e.g. list(list(name = \"source\", type = \"string\"))."
    ))
  }
  if (!is.list(message)) {
    rlang::abort("eip712_digest(): `message` must be a named list of field values.")
  }
  domain_separator <- eip712_domain_separator(
    name = domain$name,
    version = domain$version,
    chain_id = domain$chainId,
    verifying_contract = domain$verifyingContract
  )
  struct_hash <- eip712_hash_struct(primary_type, types, message)
  return(eip712_signing_digest(domain_separator, struct_hash))
}
