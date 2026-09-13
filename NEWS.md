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
