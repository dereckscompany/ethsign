# ethsign 0.2.1

## In plain English

This is a fleet housekeeping release: it changes how the package reports its own errors and how its documentation gets built, not what the package computes. Every error the package raises is now labelled with a class, so calling code can catch "this was a bad address" separately from "this couldn't be signed" instead of matching on the wording of a message. Separately, the script that regenerates the package's documentation was missing an option needed to pick up the `EthSigner` class's own per-method checks, so those checks could silently stop being regenerated; the script now matches the rest of the fleet and keeps that option on.

## Typed error conditions

All 27 `rlang::abort()` calls across `eip712.R`, `keys.R`, `secp256k1.R`, `signer.R` and `zzz.R` now go through one of four typed raisers in the new `R/conditions.R`, each signalling a condition classed under a shared `ethsign_error` domain root:

* `ethsign_validation_error` -- a public function's own argument, or a private-key / address / recovery-byte value, is malformed before any cryptographic work happens.
* `ethsign_encoding_error` -- a value cannot be encoded into the EIP-712 wire representation being hashed.
* `ethsign_signing_error` -- the ECDSA signing computation hits the astronomically unlikely `r == 0` / `s == 0` degenerate case.
* `ethsign_integrity_error` -- the package's own load-time Keccak-256 self-test fails.

Every message string is byte-identical to the bare `rlang::abort()` call it replaces, so existing `expect_error(..., regexp = ...)` checks are unaffected. `tests/testthat/test-conditions.R` adds class-based coverage for all four kinds, driven through the real abort sites (two of them, the signing and integrity kinds, via mocked lower-level primitives, since their triggering conditions cannot be reached with real inputs).

## Documentation build

`scripts/BUILD.sh`'s `cmd_document()` now sets `options(keep.source = TRUE, keep.source.pkgs = TRUE)` before calling `devtools::document()`, matching the sibling connectors. Without it, `roxyassert`'s contract roclet can silently fail to generate the per-method `assert_args_EthSigner__*` contracts for the `EthSigner` R6 class.

# ethsign 0.2.0

## In plain English

This package's Polymarket test vectors were checking the wrong thing. They were generated from `py-clob-client`, the client Polymarket archived on 2026-05-25, and they describe the retired V1 exchange. Reading the live contracts on Polygon on 2026-09-16 shows the exchange now declares itself version `"2"`, and its order has a different set of fields. So every "verified against the official client" claim in 0.1.0 was verified against a client the venue had stopped using -- the vectors were internally consistent and green, and certified a signature no deployed contract would accept.

The hashing code itself turns out to be correct: it needed no change at all. What changed is what it is checked against. 0.2.0 replaces the acceptance vectors with ones taken from the CURRENT official client and, independently, from the deployed contracts themselves.

## The chain read this rests on

`eip712Domain()` (EIP-5267, selector `0x84b0196e`) on both live exchange contracts, over a keyless Polygon RPC on 2026-09-16:

| contract | address | name | version | chainId |
| --- | --- | --- | --- | --- |
| CTF Exchange | `0xE111180000d2663C0091e4f400237545B87B996B` | `Polymarket CTF Exchange` | `2` | 137 |
| Neg Risk CTF Exchange | `0xe2222d279d744050d28e00520010520000310F59` | `Polymarket CTF Exchange` | `2` | 137 |

The EIP-712 domain separator hashes the version **string**, so `"1"` and `"2"` are different domains and produce different digests from identical order fields.

## Verification

* **V2 acceptance vectors** (`tests/testthat/test-eip712-sign.R`). `Order` digests and signatures on both the standard and the neg-risk CTF Exchange V2, plus the three-field-domain `ClobAuth` digest and signature. Generated from `Polymarket/py-clob-client-v2` at commit `215fc63a8fd6ec3a10c7edb73997c9772d8686d3` (`py-clob-client-v2` 1.1.0, `eth-account` 0.14.0, `eth-abi` 6.0.0, `eth-utils` 6.0.0) by driving `ExchangeOrderBuilderV2` directly, with a throwaway unfunded key. Cross-checked against `Polymarket/py-sdk` at `579bb2e56be9cc5d152546985870ee6ad795ec52`, which agrees field for field.
* **Anchored to the chain, not to an SDK.** Each pinned digest was independently obtained by calling `hashOrder(Order)` on the DEPLOYED exchange over a keyless Polygon RPC with the same field values. Contract and client agree byte for byte, so these vectors cannot drift with a client release.
* **The contract's own typehash.** A test hashes the V2 `Order` type string and asserts it equals the `ORDER_TYPEHASH` literal that `ctf-exchange-v2`'s `Structs.sol` pins (commit `ccc0596074f4dfd62c944fbca4de252893b82b4b`), so a drift in `encodeType` fails before any signature does.
* **A guard against the exact 0.1.0 mistake.** A test asserts that signing the same order under `version = "1"` and `version = "2"` gives different signatures.

## The V2 `Order` struct

Eleven fields, in this order, per `Structs.sol` and both python clients: `salt` (uint256), `maker` (address), `signer` (address), `tokenId` (uint256), `makerAmount` (uint256), `takerAmount` (uint256), `side` (uint8), `signatureType` (uint8), `timestamp` (uint256, unix **milliseconds**), `metadata` (bytes32), `builder` (bytes32).

V1's `taker`, `expiration`, `nonce` and `feeRateBps` are gone from the signed struct. (`expiration` still travels in the `POST /order` wire body; it is simply not signed over.)

## Compatibility

No code changed -- `eip712_digest()`, `eip712_sign()` and every other exported function behave exactly as in 0.1.0, and the existing `bytes32` / `uintN` / `address` encoders already covered every V2 field type. This release is a correction to what the package is TESTED against.

0.1.0's V1 vectors are retained, clearly labelled, in `tests/testthat/test-eip712-sign-v1-historical.R`. They are regression coverage of the hashing engine only and are explicitly **not** acceptance criteria: no signature under that domain can be accepted by any deployed Polymarket contract.

# ethsign 0.1.0

EIP-712 typed-data signing was previously narrow enough for Hyperliquid but too narrow for Polymarket: it only understood `uint64`/`uint256`, required a full four-field domain (Polymarket's login message has only three fields, and padding the missing one produces a signature for the wrong message), had no big-number safety net (a plain R number silently loses precision above about 9 quadrillion, and Polymarket's token ids run past that by 60 orders of magnitude), had no address checksum support, and could not sign a struct that contains another struct. This release removes all five limits, so the same general-purpose signer now covers both venues -- verified against real vectors from the official Polymarket python client, not just against itself.

## Features

* **The full `uintN` family.** `eip712_digest()` now encodes any `uint8` through `uint256` (in multiples of 8), each range-checked against its own width, instead of only `uint64`/`uint256`.
* **A domain built from whichever fields are present.** `eip712_digest()`'s `domain` argument no longer requires all four of `name`/`version`/`chainId`/`verifyingContract`: it hashes exactly the keys supplied, in their fixed EIP-712 order (plus the new optional `salt`). This is required for Polymarket's `ClobAuth` login message, whose domain has no `verifyingContract` -- padding one in would silently produce a valid-looking but wrong signature.
* **Big numbers past 2^53.** A `uintN` field now also accepts a decimal string or a `0x`-hex string (or a `gmp::bigz` directly), so values with no exact double-precision representation -- such as Polymarket's 77-digit conditional token ids -- sign correctly. A plain numeric above 2^53 now aborts instead of silently rounding.
* **`eth_checksum_address()`**: EIP-55 mixed-case address checksumming, to catch a mistyped or truncated address before it is signed over.
* **One level of nested structs.** A field may now name another struct (e.g. Polymarket's `Order`, or an ERC-7739 `TypedDataSign` wrapper); its type string and hash follow EIP-712's `encodeType`/`encodeData` exactly, matching the spec's own nested "Person-in-Mail" example byte for byte.
* **`eip712_sign()`**: a convenience wrapper that hashes, signs, and returns the wire-ready 65-byte `r || s || v` hex signature directly, for callers (such as Polymarket) that want the final signature rather than the intermediate digest.

## Verification

New vectors are pinned in the test suite: the EIP-712 spec's own "Ether Mail" nested-struct digest (cross-checked against `eth_account`, an independent python implementation); the full EIP-55 checksum test-vector set; and, for Polymarket specifically, an `Order` signature on both the standard and neg-risk CTF Exchange contracts plus a three-field-domain `ClobAuth` digest and signature -- all generated with the official `py-clob-client` (and its `py-order-utils`/`poly-eip712-structs` dependencies) against a throwaway, unfunded key, and reproduced byte for byte by `ethsign`.

## Compatibility

`eip712_digest()`'s signature and behaviour are unchanged for existing four-field-domain callers (e.g. the Hyperliquid connector): a full domain still hashes exactly as before.

# ethsign 0.0.2

* Hash Keccak-256 with `secretbase::keccak()` instead of `openssl::keccak()`.
  The openssl primitive depends on the system OpenSSL exposing the legacy
  `keccak-256` algorithm (only present in OpenSSL >= 3.2), so the package failed
  to load on systems with an older OpenSSL (e.g. Linux CI runners). `secretbase`
  bundles its own Keccak and is portable everywhere.

# ethsign 0.0.1

Initial release: pure-R Ethereum and EVM wallet signing primitives.

## Features

* **Signer** (`EthSigner`, via `eth_signer()` / `eth_signer_random()`): holds a
  secp256k1 private key in memory and exposes `$address` plus three signing
  paths -- `$sign_digest()` (an arbitrary 32-byte digest), `$sign_typed_data()`
  (EIP-712), and `$sign_message()` (EIP-191 `personal_sign`, the SIWE / login
  digest). The key is normalised to `raw(32)`, never exposed, and never printed.
* **Hashing & EIP-712**: `keccak256()` (original pre-FIPS-202 Keccak) and
  `eip712_digest()`, which builds the `0x1901`-prefixed typed-data signing
  digest for a single struct over atomic field types (`string`, `uint64`,
  `uint256`, `bool`, `address`, `bytes32`).
* **Keys & addresses**: `eth_keygen()` for a fresh random private key and
  `eth_address()` for address derivation from a key.
* **Signatures**: the canonical `eth_signature` object with two serializations
  -- `as_rsv()` (the `{r, s, v}` object form, e.g. Hyperliquid) and `as_hex()`
  (the 65-byte concatenated form, e.g. Polymarket).
* **Verification**: `ecrecover()` recovers the signing address from a digest and
  `(r, s, v)`, the inverse check against an `EthSigner`'s output.

## Design

* **Pure R.** No native build; the only dependencies are `gmp` (big-integer
  curve arithmetic) and `openssl` (keccak, HMAC-SHA256, secure randomness).
* **Deterministic.** ECDSA nonces are generated with RFC 6979 (HMAC-SHA256
  DRBG), so a given key and digest always yield the same signature -- signing is
  fully offline and reproducible, with no network and no funds.
* **Ethereum-correct.** EIP-2 low-s normalisation and the `v = 27 + recid`
  recovery byte; a load-time self-test aborts if the system `openssl` ships
  FIPS-202 SHA3 under the Keccak name.
* **Verified.** Reproduces the EIP-712 spec example ("Ether Mail" domain
  separator) and the official Hyperliquid Python SDK signing vectors
  (`usdSend`, `withdraw3`) exactly.
* **Validated.** Public inputs and return shapes are checked with the `assert`
  package; the package dogfoods `assert` and `roxyassert` (generated
  argument/return contracts and the exported `assert_type_eth_signature`).
