# Project an `eth_signature` to its `{r, s, v}` Object Form

Returns the signature as a `list(r, s, v)` with `r`/`s` as minimal
`0x`-hex (leading zeros stripped, matching `eth_utils.to_hex`). This is
the form venues such as Hyperliquid expect in the request body.

## Usage

``` r
as_rsv(sig)
```

## Arguments

- sig:

  (eth_signature) a signature from an
  [EthSigner](https://dereckscompany.github.io/ethsign/reference/EthSigner.md).

## Value

(list) a `list(r = <0x-hex>, s = <0x-hex>, v = <integer>)`.

## Examples

``` r
sig <- eth_signer_random()$sign_message("gm")
as_rsv(sig)
#> $r
#> [1] "0x3892094f655f48e79422e5af3b1cf036b140daecfd600cc5e803c8a7fe095385"
#> 
#> $s
#> [1] "0x420ae7a82a8a1b059f2b7b4756493718b89beb41af65439820ad06b10bf5f084"
#> 
#> $v
#> [1] 27
#> 
```
