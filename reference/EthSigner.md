# EthSigner: A Local Ethereum Wallet Signer

EthSigner: A Local Ethereum Wallet Signer

EthSigner: A Local Ethereum Wallet Signer

## Details

Holds a secp256k1 private key privately and signs digests on its behalf.
The key is normalised to `raw(32)` at construction, never exposed by any
public member, and never printed. Construct one with
[`eth_signer()`](https://dereckscompany.github.io/ethsign/reference/eth_signer.md)
(from an env var or an explicit key) or
[`eth_signer_random()`](https://dereckscompany.github.io/ethsign/reference/eth_signer_random.md)
(a throwaway key).

All signing methods return an
[eth_signature](https://dereckscompany.github.io/ethsign/reference/eth_signature.md);
serialize it with
[`as_rsv()`](https://dereckscompany.github.io/ethsign/reference/as_rsv.md)
(the `{r, s, v}` object form, e.g. Hyperliquid) or
[`as_hex()`](https://dereckscompany.github.io/ethsign/reference/as_hex.md)
(the 65-byte concatenated form, e.g. Polymarket).

## Signing paths

- `$sign_digest(digest32)`: sign an arbitrary 32-byte digest directly.

- `$sign_typed_data(...)`: hash an EIP-712 struct via
  [`eip712_digest()`](https://dereckscompany.github.io/ethsign/reference/eip712_digest.md),
  then sign it.

- `$sign_message(text)`: EIP-191 `personal_sign` over
  `"\x19Ethereum Signed Message:\n" + nbytes + text` (covers SIWE /
  login).

## Active bindings

- `address`:

  (scalar\<character\>) read-only; the lowercase `0x`-prefixed Ethereum
  address derived from the private key.

## Methods

### Public methods

- [`EthSigner$new()`](#method-EthSigner-new)

- [`EthSigner$sign_digest()`](#method-EthSigner-sign_digest)

- [`EthSigner$sign_typed_data()`](#method-EthSigner-sign_typed_data)

- [`EthSigner$sign_message()`](#method-EthSigner-sign_message)

- [`EthSigner$print()`](#method-EthSigner-print)

- [`EthSigner$clone()`](#method-EthSigner-clone)

------------------------------------------------------------------------

### Method `new()`

Initialise an EthSigner from a private key.

#### Usage

    EthSigner$new(private_key)

#### Arguments

- `private_key`:

  (scalar\<character\> \| vector\<raw, 32\>) the signing key, a
  `0x`-prefixed 64-hex string or `raw(32)`.

#### Returns

(class\<EthSigner\>) invisible self.

------------------------------------------------------------------------

### Method `sign_digest()`

Sign a 32-byte digest directly (deterministic ECDSA, RFC 6979, low-s).

#### Usage

    EthSigner$sign_digest(digest32)

#### Arguments

- `digest32`:

  (vector\<raw, 32\>) the digest to sign.

#### Returns

(eth_signature) the signature.

------------------------------------------------------------------------

### Method `sign_typed_data()`

Sign EIP-712 typed data: compute the typed-data digest via
[`eip712_digest()`](https://dereckscompany.github.io/ethsign/reference/eip712_digest.md),
then sign it.

#### Usage

    EthSigner$sign_typed_data(domain, primary_type, types, message)

#### Arguments

- `domain`:

  (list) the EIP-712 domain; see
  [`eip712_digest()`](https://dereckscompany.github.io/ethsign/reference/eip712_digest.md).

- `primary_type`:

  (scalar\<character\>) the struct name.

- `types`:

  (list) the ordered field list for `primary_type`.

- `message`:

  (list) the named field values.

#### Returns

(eth_signature) the signature.

------------------------------------------------------------------------

### Method `sign_message()`

EIP-191 `personal_sign`: keccak-256 of
`"\x19Ethereum Signed Message:\n" + nbytes + text`, then sign. This is
the digest used by Sign-In with Ethereum (SIWE) and most "sign this
message to log in" flows.

#### Usage

    EthSigner$sign_message(text)

#### Arguments

- `text`:

  (scalar\<character\>) the UTF-8 message to sign.

#### Returns

(eth_signature) the signature.

------------------------------------------------------------------------

### Method [`print()`](https://rdrr.io/r/base/print.html)

Print the signer (its address only; the private key is never shown).

#### Usage

    EthSigner$print(...)

#### Arguments

- `...`:

  Unused; for S3 compatibility.

#### Returns

Invisibly self.

------------------------------------------------------------------------

### Method `clone()`

The objects of this class are cloneable with this method.

#### Usage

    EthSigner$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
