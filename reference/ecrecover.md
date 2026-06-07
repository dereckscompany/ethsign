# Recover the Signing Address from an ECDSA Signature

Ethereum's `ecrecover`: given the signed digest and the `(r, s, v)`
signature, recovers the Ethereum address that produced it. This is the
inverse check against an
[EthSigner](https://dereckscompany.github.io/ethsign/reference/EthSigner.md)'s
output, e.g. verifying a SIWE login.

## Usage

``` r
ecrecover(digest32, r, s, v)
```

## Arguments

- digest32:

  (vector\<raw, 32\>) the signed message digest.

- r, s:

  Signature scalars; a
  [`gmp::bigz`](https://rdrr.io/pkg/gmp/man/biginteger.html), integer,
  `0x`-prefixed hex string, or `raw(32)` (e.g. the `r`/`s` of
  [`as_rsv()`](https://dereckscompany.github.io/ethsign/reference/as_rsv.md)).

- v:

  Integer; the recovery byte, `27` or `28`.

## Value

(scalar\<character\> \| NULL) the recovered lowercase `0x`-prefixed
20-byte address, or `NULL` if recovery fails.

## Examples

``` r
priv <- "0x0123456789012345678901234567890123456789012345678901234567890123"
signer <- eth_signer(priv)
digest <- keccak256("recover me")
sig <- signer$sign_digest(digest)
rsv <- as_rsv(sig)
ecrecover(digest, rsv$r, rsv$s, rsv$v) == signer$address
#> [1] TRUE
```
