# Serialize an `eth_signature` to a 65-Byte Hex String

Returns `0x` + 130 hex characters: `r(32) || s(32) || v(1)`, with `v` as
`27`/`28`. This is the concatenated form venues such as Polymarket
expect.

## Usage

``` r
as_hex(sig)
```

## Arguments

- sig:

  (eth_signature) a signature from an
  [EthSigner](https://dereckscompany.github.io/ethsign/reference/EthSigner.md).

## Value

(scalar\<character\>) a `0x`-prefixed 130-hex-character signature.

## Examples

``` r
sig <- eth_signer_random()$sign_message("gm")
as_hex(sig)
#> [1] "0xd7019d5f2e9083419274014bbddafd8a4a58f1953d6a69359fb179fe6d1acbaa37de77b50aa4e15229cd320d1b9d1da178ad83ea7ec089b6bbebe9f91f0f87881b"
```
