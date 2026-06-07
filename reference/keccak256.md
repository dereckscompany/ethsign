# Compute Keccak-256 of Raw Bytes or a UTF-8 String

Ethereum uses the original Keccak (the pre-FIPS-202 padding scheme), NOT
SHA3-256. We hash with
[`secretbase::keccak()`](https://shikokuchuo.net/secretbase/reference/keccak.html),
which bundles its own Keccak implementation and so is portable across
systems regardless of the system OpenSSL version.
([`openssl::keccak()`](https://jeroen.r-universe.dev/openssl/reference/hash.html)
depends on the system OpenSSL exposing the legacy `keccak-256`
algorithm, which only exists in OpenSSL \>= 3.2 and is absent on many
systems.)

## Usage

``` r
keccak256(x)
```

## Arguments

- x:

  (raw \| scalar\<character\>) raw bytes, or a length-1 character string
  (encoded as UTF-8 before hashing).

## Value

(vector\<raw, 32\>) a plain `raw(32)` digest.

## Examples

``` r
keccak256("") # the empty-string Ethereum vector
#>  [1] c5 d2 46 01 86 f7 23 3c 92 7e 7d b2 dc c7 03 c0 e5 00 b6 53 ca 82 27 3b 7b
#> [26] fa d8 04 5d 85 a4 70
keccak256(as.raw(c(0x12, 0x34)))
#>  [1] 56 57 0d e2 87 d7 3c d1 cb 60 92 bb 8f de e6 17 39 74 95 5f de f3 45 ae 57
#> [26] 9e e9 f4 75 ea 74 32
```
