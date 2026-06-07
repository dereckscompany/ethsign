# Package index

## Signer

The local wallet signer object and its constructors

- [`EthSigner`](https://dereckscompany.github.io/ethsign/reference/EthSigner.md)
  : EthSigner: A Local Ethereum Wallet Signer
- [`eth_signer()`](https://dereckscompany.github.io/ethsign/reference/eth_signer.md)
  : Create an EthSigner from a Private Key
- [`eth_signer_random()`](https://dereckscompany.github.io/ethsign/reference/eth_signer_random.md)
  : Create an EthSigner with a Fresh Random Key

## Hashing & EIP-712

Keccak-256 hashing and EIP-712 typed-data digests

- [`keccak256()`](https://dereckscompany.github.io/ethsign/reference/keccak256.md)
  : Compute Keccak-256 of Raw Bytes or a UTF-8 String
- [`eip712_digest()`](https://dereckscompany.github.io/ethsign/reference/eip712_digest.md)
  : Compute an EIP-712 Typed-Data Signing Digest

## Keys & Addresses

Private-key generation and Ethereum address derivation

- [`eth_keygen()`](https://dereckscompany.github.io/ethsign/reference/eth_keygen.md)
  : Generate a New Random Ethereum Private Key
- [`eth_address()`](https://dereckscompany.github.io/ethsign/reference/eth_address.md)
  : Derive an Ethereum Address from a Private Key

## Signatures

The canonical signature object and its two wire serializations

- [`eth_signature`](https://dereckscompany.github.io/ethsign/reference/eth_signature.md)
  : eth_signature: the canonical signature object

- [`as_rsv()`](https://dereckscompany.github.io/ethsign/reference/as_rsv.md)
  :

  Project an `eth_signature` to its `{r, s, v}` Object Form

- [`as_hex()`](https://dereckscompany.github.io/ethsign/reference/as_hex.md)
  :

  Serialize an `eth_signature` to a 65-Byte Hex String

- [`print(`*`<eth_signature>`*`)`](https://dereckscompany.github.io/ethsign/reference/print.eth_signature.md)
  :

  Print an `eth_signature`

## Verification

Recover the signing address from a signature

- [`ecrecover()`](https://dereckscompany.github.io/ethsign/reference/ecrecover.md)
  : Recover the Signing Address from an ECDSA Signature

## Contracts & Validators

Generated roxyassert type validators

- [`assert_type_eth_signature()`](https://dereckscompany.github.io/ethsign/reference/roxyassert-generated-asserts.md)
  : Generated assertion helpers
