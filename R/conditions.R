# File: R/conditions.R
# ethsign's typed error conditions. ethsign is a pure local signing library --
# it makes no network calls, so there is no connectcore-style transport root
# here, only ONE domain root: `ethsign_error`. Four kinds sit under it, one per
# genuinely distinct way a site can fail:
#   - `ethsign_validation_error`: a public function's own argument, or a
#     private-key / address / recovery-byte value, is malformed or violates a
#     rule BEFORE any cryptographic work happens (a bad private-key shape, an
#     unknown EIP-712 domain field, `v` not 27 or 28, no key supplied to
#     `eth_signer()`).
#   - `ethsign_encoding_error`: a value cannot be encoded into the EIP-712
#     wire representation being hashed (a `uintN` out of range or the wrong
#     R type, an unsupported field type, a `bytes32` that is not `raw(32)`,
#     a struct message missing a field its type declares).
#   - `ethsign_signing_error`: the ECDSA signing computation itself hits an
#     astronomically unlikely degenerate case (`r == 0` or `s == 0`) that
#     would need a nonce retry -- not a bad input and not an encoding
#     failure, a computation invariant.
#   - `ethsign_integrity_error`: the package's own load-time Keccak-256
#     self-test fails, meaning the hashing primitive itself is wrong. This
#     can only fire from `.onLoad()`, never from a user call.
#
# Backward compatibility is a hard contract: every message string stays
# byte-identical to the bare `rlang::abort()` call it replaced. The classes
# are purely additive.

#' Raise a Typed ethsign Input-Validation Error
#'
#' Signals a condition classed `c("ethsign_validation_error", "ethsign_error")`
#' (on top of rlang's error classes) for a public function's own argument, or a
#' private-key / address / recovery-byte value, that is malformed or violates a
#' rule before any cryptographic work happens (a bad private-key shape, an
#' unknown EIP-712 domain field, a `v` that is not 27 or 28, no key supplied to
#' [eth_signer()]). `ethsign_error` is the package's single domain root -- there
#' is no separate transport root, because ethsign makes no network calls. The
#' `message` is passed through verbatim, so the string stays byte-identical to
#' the bare `rlang::abort()` call this replaced.
#'
#' @param message (scalar<character>) the condition message, passed through
#'   verbatim to [rlang::abort()].
#' @param ... structured fields stored on the condition, read with `e[["field"]]`.
#'   Forwarded to [rlang::abort()].
#' @param call (environment) the environment blamed in the traceback; defaults to
#'   the caller via [rlang::caller_env()].
#' @return (class<ethsign_error>) never returns normally; signals the classed
#'   condition described above.
#' @importFrom rlang abort caller_env
#' @keywords internal
#' @noassert
#' @noRd
abort_ethsign_validation_error <- function(message, ..., call = rlang::caller_env()) {
  return(rlang::abort(
    message = message,
    class = c("ethsign_validation_error", "ethsign_error"),
    ...,
    call = call
  ))
}

#' Raise a Typed ethsign Wire-Encoding Error
#'
#' Signals a condition classed `c("ethsign_encoding_error", "ethsign_error")`
#' (on top of rlang's error classes) for a value that cannot be encoded into
#' the EIP-712 wire representation being hashed: a `uintN` value out of range
#' or of the wrong R type, an unsupported or malformed field type, a `bytes32`
#' value that is not `raw(32)`, an `address` that is not 20 bytes, or a struct
#' message missing a field its type declares. `ethsign_error` is the package's
#' single domain root (see [abort_ethsign_validation_error]); an encoding
#' failure is a distinct kind from an input-validation failure, so it carries
#' its own subclass. The `message` is passed through verbatim, so the string
#' stays byte-identical to the bare `rlang::abort()` call this replaced.
#'
#' @param message (scalar<character>) the condition message, passed through
#'   verbatim to [rlang::abort()].
#' @param ... structured fields stored on the condition, read with `e[["field"]]`.
#'   Forwarded to [rlang::abort()].
#' @param call (environment) the environment blamed in the traceback; defaults to
#'   the caller via [rlang::caller_env()].
#' @return (class<ethsign_error>) never returns normally; signals the classed
#'   condition described above.
#' @importFrom rlang abort caller_env
#' @keywords internal
#' @noassert
#' @noRd
abort_ethsign_encoding_error <- function(message, ..., call = rlang::caller_env()) {
  return(rlang::abort(
    message = message,
    class = c("ethsign_encoding_error", "ethsign_error"),
    ...,
    call = call
  ))
}

#' Raise a Typed ethsign Signing-Computation Error
#'
#' Signals a condition classed `c("ethsign_signing_error", "ethsign_error")`
#' (on top of rlang's error classes) for an astronomically unlikely degenerate
#' case in the ECDSA signing computation itself -- the RFC 6979 nonce
#' producing a zero `r` or a zero `s` -- which would need a nonce retry the
#' current implementation does not attempt. This is neither a bad input (the
#' private key and digest are well-formed) nor an encoding failure (nothing
#' is being serialised); it is a computation invariant violated at signing
#' time. `ethsign_error` is the package's single domain root (see
#' [abort_ethsign_validation_error]). The `message` is passed through
#' verbatim, so the string stays byte-identical to the bare `rlang::abort()`
#' call this replaced.
#'
#' @param message (scalar<character>) the condition message, passed through
#'   verbatim to [rlang::abort()].
#' @param ... structured fields stored on the condition, read with `e[["field"]]`.
#'   Forwarded to [rlang::abort()].
#' @param call (environment) the environment blamed in the traceback; defaults to
#'   the caller via [rlang::caller_env()].
#' @return (class<ethsign_error>) never returns normally; signals the classed
#'   condition described above.
#' @importFrom rlang abort caller_env
#' @keywords internal
#' @noassert
#' @noRd
abort_ethsign_signing_error <- function(message, ..., call = rlang::caller_env()) {
  return(rlang::abort(
    message = message,
    class = c("ethsign_signing_error", "ethsign_error"),
    ...,
    call = call
  ))
}

#' Raise a Typed ethsign Load-Time Integrity Error
#'
#' Signals a condition classed `c("ethsign_integrity_error", "ethsign_error")`
#' (on top of rlang's error classes) for the package's own load-time
#' Keccak-256 self-test failing, meaning the hashing primitive underneath the
#' whole signing path is not the original Keccak-256 -- a wrong dependency
#' version silently producing invalid Ethereum signatures. This can only fire
#' from `.onLoad()`, never from a user call, so it is a distinct kind from
#' both input validation and EIP-712 encoding. `ethsign_error` is the
#' package's single domain root (see [abort_ethsign_validation_error]). The
#' `message` is passed through verbatim, so the string stays byte-identical to
#' the bare `rlang::abort()` call this replaced.
#'
#' @param message (scalar<character>) the condition message, passed through
#'   verbatim to [rlang::abort()].
#' @param ... structured fields stored on the condition, read with `e[["field"]]`.
#'   Forwarded to [rlang::abort()].
#' @param call (environment) the environment blamed in the traceback; defaults to
#'   the caller via [rlang::caller_env()].
#' @return (class<ethsign_error>) never returns normally; signals the classed
#'   condition described above.
#' @importFrom rlang abort caller_env
#' @keywords internal
#' @noassert
#' @noRd
abort_ethsign_integrity_error <- function(message, ..., call = rlang::caller_env()) {
  return(rlang::abort(
    message = message,
    class = c("ethsign_integrity_error", "ethsign_error"),
    ...,
    call = call
  ))
}
