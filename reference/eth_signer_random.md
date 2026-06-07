# Create an EthSigner with a Fresh Random Key

Convenience wrapper around
[`eth_keygen()`](https://dereckscompany.github.io/ethsign/reference/eth_keygen.md)
for tests and throwaway signers.

## Usage

``` r
eth_signer_random()
```

## Value

(class\<EthSigner\>) a signer backed by a new random key.

## Examples

``` r
signer <- eth_signer_random()
signer$address
#> [1] "0x68d2fc8c22de778a456bccac3e4102ba1ea47e7a"
```
