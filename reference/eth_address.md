# Derive an Ethereum Address from a Private Key

Derives the secp256k1 public key and returns its Ethereum address: the
lowercase `0x`-prefixed last 20 bytes of
`keccak256(pubkey_x || pubkey_y)`.

## Usage

``` r
eth_address(private_key)
```

## Arguments

- private_key:

  (scalar\<character\> \| vector\<raw, 32\>) the signing key, a
  `0x`-prefixed 64-hex string or `raw(32)`.

## Value

(scalar\<character\>) the lowercase `0x`-prefixed 20-byte address.

## Examples

``` r
eth_address("0x0123456789012345678901234567890123456789012345678901234567890123")
#> [1] "0x14791697260e4c9a71f18484c9f997b308e59325"
```
