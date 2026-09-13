# File: R/eip712.R
# General EIP-712 structured-data hashing: the full uintN family, an
# EIP-712 domain built from whichever of its five fields are present, and
# one-level nested struct references (a field type that names another struct
# in the type map encodes as that struct's hashStruct -- e.g. an ERC-7739
# TypedDataSign wrapper). Field types covered: string, bytes32, uintN (N a
# multiple of 8 in 8..256), bool, address, and struct references.
#
# Representation:
#   types_map : named list, struct name -> unnamed list of list(name, type)
#               (field order within a struct matters; struct order does not)
#   message   : named list, values looked up by field name (a struct-typed
#               field holds that struct's own named list of field values)

#' Encode a Single Struct's Own Type String (no referenced definitions)
#' @param struct_name Character; the struct name.
#' @param fields Unnamed list of `list(name, type)` in definition order.
#' @return Character; e.g. `"Mail(Person from,Person to,string contents)"`.
#' @keywords internal
#' @noRd
eip712_encode_type_one <- function(struct_name, fields) {
  parts <- vapply(fields, function(f) paste(f$type, f$name), character(1))
  return(paste0(struct_name, "(", paste(parts, collapse = ","), ")"))
}

#' Collect the Struct Types a Struct Transitively References
#'
#' Per EIP-712 `encodeType`: the struct types referenced by field types
#' (directly, or via another referenced struct), excluding `primary_type`
#' itself, sorted alphabetically.
#'
#' @param primary_type Character; the struct name.
#' @param types_map Named list; struct name -> unnamed list of
#'   `list(name, type)`.
#' @return Character vector; referenced struct names, alphabetically sorted.
#' @keywords internal
#' @noRd
eip712_collect_referenced_types <- function(primary_type, types_map) {
  visited <- character(0)
  referenced <- character(0)
  queue <- primary_type
  while (length(queue) > 0L) {
    current <- queue[[1]]
    queue <- queue[-1]
    if (current %in% visited) {
      next
    }
    visited <- c(visited, current)
    for (f in types_map[[current]]) {
      if (f$type %in% names(types_map) && !identical(f$type, primary_type)) {
        if (!(f$type %in% referenced)) {
          referenced <- c(referenced, f$type)
        }
        queue <- c(queue, f$type)
      }
    }
  }
  return(sort(referenced))
}

#' Encode an EIP-712 Type String
#'
#' Produces `"Primary(type1 name1,...)"` followed by the alphabetically
#' sorted definitions of every struct type it (transitively) references, per
#' EIP-712's `encodeType`:
#' `PrimaryType(members)Ref0(members)Ref1(members)...`. With no referenced
#' structs this is just the primary type's own definition.
#'
#' @param primary_type Character; the struct name.
#' @param types_map Named list; struct name -> unnamed list of
#'   `list(name, type)` in definition order. Must include `primary_type`.
#' @return Character; the canonical type string.
#' @keywords internal
#' @noRd
eip712_encode_type <- function(primary_type, types_map) {
  own <- eip712_encode_type_one(primary_type, types_map[[primary_type]])
  referenced <- eip712_collect_referenced_types(primary_type, types_map)
  extra <- vapply(
    referenced,
    function(rt) eip712_encode_type_one(rt, types_map[[rt]]),
    character(1)
  )
  return(paste0(own, paste(extra, collapse = "")))
}

#' Keccak-256 of an EIP-712 Type String
#' @inheritParams eip712_encode_type
#' @return `raw(32)`; the type hash.
#' @keywords internal
#' @noRd
eip712_type_hash <- function(primary_type, types_map) {
  return(keccak256(eip712_encode_type(primary_type, types_map)))
}

#' Coerce an EIP-712 `uintN` Field Value to a `gmp::bigz`
#'
#' Accepts a `gmp::bigz`, a whole-number double/integer (only when exactly
#' representable, i.e. `abs(value) <= 2^53`), a decimal string, or a
#' `0x`-prefixed hex string. A plain R double cannot represent an integer
#' above `2^53` exactly, so bigger values (e.g. Polymarket's 77-digit token
#' ids) must be passed as a string or a `gmp::bigz`. Not yet range-checked
#' against the field's specific `uintN` width -- see the caller.
#'
#' @param value A `gmp::bigz`, numeric, or character (decimal or `0x`-hex).
#' @return A scalar `gmp::bigz`.
#' @importFrom gmp as.bigz
#' @importFrom rlang abort
#' @keywords internal
#' @noRd
eip712_coerce_uint <- function(value) {
  if (inherits(value, "bigz")) {
    return(value)
  }
  if (is.numeric(value) && length(value) == 1L) {
    if (is.na(value)) {
      rlang::abort("eip712: a uintN value must not be NA.")
    }
    if (abs(value) > 2^53) {
      rlang::abort(paste0(
        "eip712: a numeric uintN value above 2^53 cannot be represented ",
        "exactly as an R double (got ",
        format(value, scientific = FALSE),
        "). Pass it as a decimal string, a 0x-hex string, or a gmp::bigz ",
        "instead."
      ))
    }
    if (value != trunc(value)) {
      rlang::abort("eip712: a uintN value must be a whole number.")
    }
    return(gmp::as.bigz(value))
  }
  if (is.character(value) && length(value) == 1L && grepl("^(0[xX][0-9a-fA-F]+|[0-9]+)$", value)) {
    return(gmp::as.bigz(value))
  }
  rlang::abort(paste0(
    "eip712: a uintN value must be a gmp::bigz, a whole number (abs <= ",
    "2^53), a decimal string, or a 0x-prefixed hex string."
  ))
}

#' Encode a Single EIP-712 Field Value to 32 Bytes
#'
#' Every EIP-712 field value encodes to exactly 32 bytes: atomic values
#' directly, and a field whose type names another struct in `types_map` (one
#' level of nesting) as that struct's `hashStruct` (EIP-712 `encodeData`).
#'
#' @param type Character; the field's EIP-712 type -- `string`, `bytes32`, a
#'   `uintN` width (`uint8`..`uint256`, N a multiple of 8), `bool`,
#'   `address`, or the name of another struct in `types_map`.
#' @param value The R value to encode (a named list of field values when
#'   `type` names a struct).
#' @param types_map Named list, struct name -> field list, or `NULL` when
#'   `type` cannot be a struct reference (e.g. inside the fixed
#'   `EIP712Domain`).
#' @return `raw(32)`.
#' @importFrom gmp as.bigz
#' @importFrom rlang abort
#' @keywords internal
#' @noRd
eip712_encode_value <- function(type, value, types_map = NULL) {
  if (!is.null(types_map) && type %in% names(types_map)) {
    return(eip712_hash_struct(type, types_map, value))
  }
  if (type == "string") {
    return(keccak256(as.character(value))) # hash of UTF-8 bytes
  }
  if (type == "bytes32") {
    if (!is.raw(value) || length(value) != 32) {
      rlang::abort("eip712: a `bytes32` value must be raw(32).")
    }
    return(value)
  }
  if (grepl("^uint[0-9]+$", type)) {
    n_bits <- as.integer(sub("^uint", "", type))
    if (n_bits %% 8 != 0 || n_bits < 8 || n_bits > 256) {
      rlang::abort(paste0(
        "eip712: unsupported field type '",
        type,
        "' (uintN needs N a ",
        "multiple of 8 in [8, 256])."
      ))
    }
    bz <- eip712_coerce_uint(value)
    limit <- gmp::as.bigz(2)^n_bits
    if (bz < 0 || bz >= limit) {
      rlang::abort(paste0(
        "eip712: value out of range for ",
        type,
        " (must be in [0, 2^",
        n_bits,
        ")): ",
        as.character(bz)
      ))
    }
    return(bigz2raw32(bz))
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
    "eip712: unsupported field type '",
    type,
    "'. Supported: string, bytes32, uintN (N a multiple of 8 in 8..256), ",
    "bool, address, or a struct name defined in `types`."
  ))
}

#' Hash an EIP-712 Struct
#'
#' Computes `keccak(typeHash || enc(field1) || enc(field2) || ...)`. Fields
#' are encoded in TYPE-DEFINITION order; extra message keys are ignored,
#' matching eth_account's `encode_typed_data`. A field whose type names
#' another struct in `types_map` recurses into that struct's own
#' `hashStruct` (one level of nesting is all this package resolves).
#'
#' @param primary_type Character; the struct name.
#' @param types_map Named list; struct name -> field list. Must include
#'   `primary_type`.
#' @param message Named list of field values.
#' @return `raw(32)`; the struct hash.
#' @importFrom rlang abort
#' @keywords internal
#' @noRd
eip712_hash_struct <- function(primary_type, types_map, message) {
  fields <- types_map[[primary_type]]
  data <- eip712_type_hash(primary_type, types_map)
  for (f in fields) {
    if (!f$name %in% names(message)) {
      rlang::abort(paste0("eip712: message is missing field '", f$name, "'."))
    }
    data <- c(data, eip712_encode_value(f$type, message[[f$name]], types_map))
  }
  return(keccak256(data))
}

# ---- EIP-712 domain (partial: only the keys present are hashed) --------------

EIP712_DOMAIN_FIELD_TYPES <- list(
  name = "string",
  version = "string",
  chainId = "uint256",
  verifyingContract = "address",
  salt = "bytes32"
)

#' Build the `EIP712Domain` Field List from the Keys Present
#'
#' EIP-712 domains are partial: a signer only hashes the domain fields the
#' venue actually declares, in the fixed canonical order (name, version,
#' chainId, verifyingContract, salt) -- e.g. Polymarket's `ClobAuth` domain
#' has only `name`, `version`, `chainId` (no `verifyingContract`), and
#' padding a missing field with zeros would produce a different, wrong
#' signature.
#'
#' @param domain Named list; a non-empty subset of `name`, `version`,
#'   `chainId`, `verifyingContract`, `salt`.
#' @return Unnamed list of `list(name, type)`, in canonical order, for the
#'   keys present in `domain`.
#' @importFrom rlang abort
#' @keywords internal
#' @noRd
eip712_domain_fields <- function(domain) {
  present <- intersect(names(EIP712_DOMAIN_FIELD_TYPES), names(domain))
  if (length(present) == 0L) {
    rlang::abort(paste0(
      "eip712: `domain` must include at least one of name, version, ",
      "chainId, verifyingContract, salt."
    ))
  }
  return(lapply(present, function(key) list(name = key, type = EIP712_DOMAIN_FIELD_TYPES[[key]])))
}

#' Compute the EIP-712 Domain Separator
#'
#' Hashes `EIP712Domain` built from whichever of its five fields are present
#' in `domain`, in canonical order -- see [eip712_domain_fields()].
#'
#' @param domain Named list; a non-empty subset of `name`, `version`,
#'   `chainId`, `verifyingContract`, `salt`.
#' @return `raw(32)`; the domain separator.
#' @keywords internal
#' @noRd
eip712_domain_separator <- function(domain) {
  fields <- eip712_domain_fields(domain)
  field_names <- vapply(fields, function(f) f$name, character(1))
  types_map <- list(EIP712Domain = fields)
  return(eip712_hash_struct("EIP712Domain", types_map, domain[field_names]))
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

# ---- public entry points ------------------------------------------------------

#' Normalise the `types` Argument to a Struct-Name -> Field-List Map
#'
#' `types` accepts two shapes: the original single-struct shape (an unnamed
#' list of `list(name, type)`, wrapped here under `primary_type`), or a full
#' struct map (a named list of struct name -> field list) for callers with
#' nested structs, where a field's `type` may name another key of the map.
#'
#' @param types Unnamed list of `list(name, type)`, or a named list of struct
#'   name -> field list; see [eip712_digest()].
#' @param primary_type Character; the struct name.
#' @return Named list; struct name -> field list, including `primary_type`.
#' @importFrom rlang abort
#' @keywords internal
#' @noRd
eip712_normalise_types <- function(types, primary_type) {
  if (is.null(names(types)) || all(!nzchar(names(types)))) {
    types_map <- list()
    types_map[[primary_type]] <- types
    return(types_map)
  }
  if (!primary_type %in% names(types)) {
    rlang::abort(paste0(
      "eip712_digest(): `types` must include a definition for `primary_type` ",
      "('",
      primary_type,
      "')."
    ))
  }
  return(types)
}

#' Compute an EIP-712 Typed-Data Signing Digest
#'
#' Hashes a struct under its domain and returns the `0x1901`-prefixed digest
#' ready to sign (the value an [EthSigner] passes to `$sign_digest()`). This
#' is the standard typed-data digest used by EVM venues such as Hyperliquid
#' and Polymarket.
#'
#' Field types: `string`, `uintN` (N a multiple of 8 in 8..256), `bool`,
#' `address`, `bytes32`, and one level of struct nesting (a field whose type
#' names another struct, e.g. an ERC-7739 `TypedDataSign` wrapper). Arrays are
#' out of scope.
#'
#' @param domain (list) the EIP-712 domain: a non-empty subset of `name`
#'   (character), `version` (character), `chainId` (numeric, a decimal/`0x`
#'   string, or `gmp::bigz`), `verifyingContract` (a `0x`-prefixed 20-byte
#'   address), and `salt` (`raw(32)`). Only the keys present are hashed, in
#'   canonical order -- e.g. Polymarket's `ClobAuth` domain omits
#'   `verifyingContract`.
#' @param primary_type (scalar<character>) the struct name, e.g. `"Order"`.
#' @param types (list) either the field list for `primary_type` (an unnamed
#'   list of `list(name, type)`, in definition order), or -- when a field's
#'   type names another struct -- a named list mapping every referenced
#'   struct name (including `primary_type`) to its own field list.
#' @param message (list) field values, looked up by field name. A field whose
#'   type names another struct holds that struct's own named list of values.
#' @return (vector<raw, 32>) the signing digest.
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
  assert_args_eip712_digest(domain, primary_type, types, message)
  if (!is.list(domain) || is.null(names(domain))) {
    rlang::abort(paste0(
      "eip712_digest(): `domain` must be a named list containing a non-empty ",
      "subset of name, version, chainId, verifyingContract, salt, e.g. ",
      "list(name = \"Exchange\", version = \"1\", chainId = 1337, ",
      "verifyingContract = \"0x0000000000000000000000000000000000000000\")."
    ))
  }
  unknown_domain_fields <- setdiff(names(domain), names(EIP712_DOMAIN_FIELD_TYPES))
  if (length(unknown_domain_fields) > 0L) {
    rlang::abort(paste0(
      "eip712_digest(): unknown domain field(s): ",
      paste(unknown_domain_fields, collapse = ", "),
      ". Valid EIP712Domain fields: ",
      paste(names(EIP712_DOMAIN_FIELD_TYPES), collapse = ", "),
      "."
    ))
  }
  if (!is.character(primary_type) || length(primary_type) != 1L) {
    rlang::abort("eip712_digest(): `primary_type` must be a length-1 character string, e.g. \"Order\".")
  }
  if (!is.list(types) || length(types) == 0L) {
    rlang::abort(paste0(
      "eip712_digest(): `types` must be a non-empty unnamed list of ",
      "list(name=, type=) for `primary_type`, or a named list mapping every ",
      "referenced struct name to its own field list."
    ))
  }
  if (!is.list(message)) {
    rlang::abort("eip712_digest(): `message` must be a named list of field values.")
  }
  types_map <- eip712_normalise_types(types, primary_type)
  domain_separator <- eip712_domain_separator(domain)
  struct_hash <- eip712_hash_struct(primary_type, types_map, message)
  return(assert_return_eip712_digest(eip712_signing_digest(domain_separator, struct_hash)))
}

#' Sign EIP-712 Typed Data and Return the 65-Byte Hex Signature
#'
#' Convenience wrapper for venues (e.g. Polymarket) that want the wire
#' signature directly: hashes `message` via [eip712_digest()], signs it with
#' `signer`, and returns the 65-byte `r(32) || s(32) || v(1)` hex form (see
#' [as_hex()]).
#'
#' @param signer (class<EthSigner>) the wallet signer.
#' @param domain (list) the EIP-712 domain; see [eip712_digest()].
#' @param types (list) the field list for `primary_type`, or a struct map for
#'   nested structs; see [eip712_digest()].
#' @param primary_type (scalar<character>) the struct name.
#' @param message (list) the named field values.
#' @return (scalar<character>) a `0x`-prefixed 130-hex-character signature
#'   (`r(32) || s(32) || v(1)`, `v` = 27 or 28).
#'
#' @examples
#' signer <- eth_signer_random()
#' domain <- list(
#'   name = "Exchange",
#'   version = "1",
#'   chainId = 1337,
#'   verifyingContract = "0x0000000000000000000000000000000000000000"
#' )
#' types <- list(list(name = "source", type = "string"))
#' eip712_sign(signer, domain, types, "Agent", list(source = "a"))
#'
#' @export
eip712_sign <- function(signer, domain, types, primary_type, message) {
  assert_args_eip712_sign(signer, domain, types, primary_type, message)
  sig <- signer$sign_typed_data(domain, primary_type, types, message)
  return(assert_return_eip712_sign(as_hex(sig)))
}
