# Generate a New Random Ethereum Private Key

Draws 32 cryptographically secure random bytes from
[`openssl::rand_bytes()`](https://jeroen.r-universe.dev/openssl/reference/rand_bytes.html)
and returns them as a `0x`-prefixed 64-hex string, rejecting the
(astronomically improbable) draws outside the valid secp256k1 scalar
range `(0, n)`.

## Usage

``` r
eth_keygen()
```

## Value

(scalar\<character\>) a `0x`-prefixed 64-hex private key.

## Examples

``` r
priv <- eth_keygen()
eth_address(priv)
#> [1] "0x0261798cd0959a2d3747d29ed7a7efbf048aa45a"
```
