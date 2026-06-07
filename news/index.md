# Changelog

## ethsign 0.0.2

- Hash Keccak-256 with
  [`secretbase::keccak()`](https://shikokuchuo.net/secretbase/reference/keccak.html)
  instead of
  [`openssl::keccak()`](https://jeroen.r-universe.dev/openssl/reference/hash.html).
  The openssl primitive depends on the system OpenSSL exposing the
  legacy `keccak-256` algorithm (only present in OpenSSL \>= 3.2), so
  the package failed to load on systems with an older OpenSSL
  (e.g. Linux CI runners). `secretbase` bundles its own Keccak and is
  portable everywhere.

## ethsign 0.0.1

Initial release: pure-R Ethereum and EVM wallet signing primitives.

### Features

- **Signer** (`EthSigner`, via
  [`eth_signer()`](https://dereckscompany.github.io/ethsign/reference/eth_signer.md)
  /
  [`eth_signer_random()`](https://dereckscompany.github.io/ethsign/reference/eth_signer_random.md)):
  holds a secp256k1 private key in memory and exposes `$address` plus
  three signing paths – `$sign_digest()` (an arbitrary 32-byte digest),
  `$sign_typed_data()` (EIP-712), and `$sign_message()` (EIP-191
  `personal_sign`, the SIWE / login digest). The key is normalised to
  `raw(32)`, never exposed, and never printed.
- **Hashing & EIP-712**:
  [`keccak256()`](https://dereckscompany.github.io/ethsign/reference/keccak256.md)
  (original pre-FIPS-202 Keccak) and
  [`eip712_digest()`](https://dereckscompany.github.io/ethsign/reference/eip712_digest.md),
  which builds the `0x1901`-prefixed typed-data signing digest for a
  single struct over atomic field types (`string`, `uint64`, `uint256`,
  `bool`, `address`, `bytes32`).
- **Keys & addresses**:
  [`eth_keygen()`](https://dereckscompany.github.io/ethsign/reference/eth_keygen.md)
  for a fresh random private key and
  [`eth_address()`](https://dereckscompany.github.io/ethsign/reference/eth_address.md)
  for address derivation from a key.
- **Signatures**: the canonical `eth_signature` object with two
  serializations –
  [`as_rsv()`](https://dereckscompany.github.io/ethsign/reference/as_rsv.md)
  (the `{r, s, v}` object form, e.g. Hyperliquid) and
  [`as_hex()`](https://dereckscompany.github.io/ethsign/reference/as_hex.md)
  (the 65-byte concatenated form, e.g. Polymarket).
- **Verification**:
  [`ecrecover()`](https://dereckscompany.github.io/ethsign/reference/ecrecover.md)
  recovers the signing address from a digest and `(r, s, v)`, the
  inverse check against an `EthSigner`’s output.

### Design

- **Pure R.** No native build; the only dependencies are `gmp`
  (big-integer curve arithmetic) and `openssl` (keccak, HMAC-SHA256,
  secure randomness).
- **Deterministic.** ECDSA nonces are generated with RFC 6979
  (HMAC-SHA256 DRBG), so a given key and digest always yield the same
  signature – signing is fully offline and reproducible, with no network
  and no funds.
- **Ethereum-correct.** EIP-2 low-s normalisation and the
  `v = 27 + recid` recovery byte; a load-time self-test aborts if the
  system `openssl` ships FIPS-202 SHA3 under the Keccak name.
- **Verified.** Reproduces the EIP-712 spec example (“Ether Mail” domain
  separator) and the official Hyperliquid Python SDK signing vectors
  (`usdSend`, `withdraw3`) exactly.
- **Validated.** Public inputs and return shapes are checked with the
  `assert` package; the package dogfoods `assert` and `roxyassert`
  (generated argument/return contracts and the exported
  `assert_type_eth_signature`).
