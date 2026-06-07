# Create an EthSigner from a Private Key

Returns an
[EthSigner](https://dereckscompany.github.io/ethsign/reference/EthSigner.md)
for the given key. By default the key is read from the `ETH_PRIVATE_KEY`
environment variable so it never appears in code or history; pass
`private_key` explicitly to override.

## Usage

``` r
eth_signer(private_key = Sys.getenv("ETH_PRIVATE_KEY"))
```

## Arguments

- private_key:

  (scalar\<character\> \| vector\<raw, 32\>) the signing key, a
  `0x`-prefixed 64-hex string or `raw(32)`. Defaults to
  `Sys.getenv("ETH_PRIVATE_KEY")`.

## Value

(class\<EthSigner\>) the signer.

## Examples

``` r
signer <- eth_signer(
  "0x0123456789012345678901234567890123456789012345678901234567890123"
)
signer$address
#> [1] "0x14791697260e4c9a71f18484c9f997b308e59325"
```
