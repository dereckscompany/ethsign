# Getting Started with ethsign

`ethsign` provides the cryptographic primitives needed to sign Ethereum
and EVM messages in pure R: keccak-256 hashing, secp256k1 ECDSA (with
the Ethereum recovery id and EIP-2 low-s normalisation), EIP-712
typed-data digests, EIP-191 `personal_sign`, and address derivation.

It is **not** a wallet: there are no funds, no balances, no chain
connection, and no broadcasting. It is the signing maths plus a small
\[EthSigner\] object that holds a private key in memory. What you do
with the resulting signature is up to your other tooling.

> **A note on responsibility.** This package handles private keys and
> produces signatures that can authorize real transactions. You are
> responsible for how you use it and for keeping your keys safe.

## Installation

``` r

renv::install("dereckscompany/ethsign")

# or, if you use remotes instead of renv:
# install.packages("remotes")
# remotes::install_github("dereckscompany/ethsign")
```

## Creating a signer

An `EthSigner` holds a secp256k1 private key privately and signs on its
behalf. The key is normalised to `raw(32)` at construction, never
exposed by any public member, and never printed.

In real use, read the key from the `ETH_PRIVATE_KEY` environment
variable so it never appears in code or history:

``` r

signer <- eth_signer() # reads ETH_PRIVATE_KEY
```

For a throwaway key (tests, scratch work), use
[`eth_signer_random()`](https://dereckscompany.github.io/ethsign/reference/eth_signer_random.md).
For this vignette we pass an explicit, well-known test key so the
printed output is reproducible – this is the canonical eth_account /
Hyperliquid example key:

``` r

testkey <- "0x0123456789012345678901234567890123456789012345678901234567890123"
signer <- eth_signer(testkey)

signer$address
#> [1] "0x14791697260e4c9a71f18484c9f997b308e59325"
signer
#> <EthSigner>
#>   address: 0x14791697260e4c9a71f18484c9f997b308e59325
```

The `$address` is the lowercase `0x`-prefixed last 20 bytes of
`keccak256(pubkey_x || pubkey_y)`. You can derive it without a signer
too:

``` r

eth_address(testkey)
#> [1] "0x14791697260e4c9a71f18484c9f997b308e59325"
```

## Hashing

Ethereum uses the original (pre-FIPS-202) Keccak, not SHA3-256.
[`keccak256()`](https://dereckscompany.github.io/ethsign/reference/keccak256.md)
accepts a UTF-8 string or raw bytes and returns a plain `raw(32)`:

``` r

keccak256("") # the canonical empty-string Ethereum vector
#>  [1] c5 d2 46 01 86 f7 23 3c 92 7e 7d b2 dc c7 03 c0 e5 00 b6 53 ca 82 27 3b 7b
#> [26] fa d8 04 5d 85 a4 70
keccak256(as.raw(c(0x12, 0x34)))
#>  [1] 56 57 0d e2 87 d7 3c d1 cb 60 92 bb 8f de e6 17 39 74 95 5f de f3 45 ae 57
#> [26] 9e e9 f4 75 ea 74 32
```

## Signing EIP-712 typed data

EIP-712 is the dominant signing scheme on EVM venues. `ethsign` builds
the `0x1901`-prefixed signing digest for a single struct over atomic
field types (`string`, `uint64`, `uint256`, `bool`, `address`,
`bytes32`).

The domain is a named list; the types are an **ordered** list of
`list(name, type)`; the message supplies the field values by name. Here
is a Hyperliquid `usdSend` user action, an exact reproduction of the
official Hyperliquid Python SDK testnet vector:

``` r

domain <- list(
  name = "HyperliquidSignTransaction",
  version = "1",
  chainId = 421614,
  verifyingContract = "0x0000000000000000000000000000000000000000"
)

types <- list(
  list(name = "hyperliquidChain", type = "string"),
  list(name = "destination", type = "string"),
  list(name = "amount", type = "string"),
  list(name = "time", type = "uint64")
)

message <- list(
  hyperliquidChain = "Testnet",
  destination = "0x5e9ee1089755c3435139848e47e6635505d5a13a",
  amount = "1",
  time = 1687816341423
)

sig <- signer$sign_typed_data(domain, "HyperliquidTransaction:UsdSend", types, message)
sig
#> <eth_signature>
#>   r: 0x637b37dd731507cdd24f46532ca8ba6eec616952c56218baeff04144e4a77073 
#>   s: 0x11a6a24900e6e314136d2592e2f8d502cd89b7c15b198e1bee043c9589f9fad7 
#>   v: 27
```

If you need the digest on its own (for example to verify it, or to sign
it later with `$sign_digest()`), compute it directly with
[`eip712_digest()`](https://dereckscompany.github.io/ethsign/reference/eip712_digest.md):

``` r

digest <- eip712_digest(domain, "HyperliquidTransaction:UsdSend", types, message)
digest
#>  [1] ca cf 75 85 cc 49 ca 60 c6 c5 fb 30 01 e2 26 c0 ca 03 c4 62 52 c8 93 ee a5
#> [26] 74 c7 89 07 b7 ce be
```

## The two serializations

A signature is the same object regardless of venue; only the wire format
differs.
[`as_rsv()`](https://dereckscompany.github.io/ethsign/reference/as_rsv.md)
gives the `{r, s, v}` object form (e.g. Hyperliquid, with `r`/`s` as
minimal `0x`-hex);
[`as_hex()`](https://dereckscompany.github.io/ethsign/reference/as_hex.md)
gives the 65-byte concatenated `r`/`s`/`v` hex string (e.g. Polymarket):

``` r

as_rsv(sig)
#> $r
#> [1] "0x637b37dd731507cdd24f46532ca8ba6eec616952c56218baeff04144e4a77073"
#> 
#> $s
#> [1] "0x11a6a24900e6e314136d2592e2f8d502cd89b7c15b198e1bee043c9589f9fad7"
#> 
#> $v
#> [1] 27

as_hex(sig)
#> [1] "0x637b37dd731507cdd24f46532ca8ba6eec616952c56218baeff04144e4a7707311a6a24900e6e314136d2592e2f8d502cd89b7c15b198e1bee043c9589f9fad71b"
```

## Verifying with `ecrecover`

[`ecrecover()`](https://dereckscompany.github.io/ethsign/reference/ecrecover.md)
is Ethereum’s signature-to-address recovery: given the signed digest and
the `(r, s, v)` triple, it returns the address that produced the
signature. Recovering the test key’s own address closes the loop:

``` r

rsv <- as_rsv(sig)
recovered <- ecrecover(digest, rsv$r, rsv$s, rsv$v)

recovered
#> [1] "0x14791697260e4c9a71f18484c9f997b308e59325"
recovered == signer$address
#> [1] TRUE
```

## Signing a login message

`$sign_message()` applies the EIP-191 `personal_sign` prefix
(`"\x19Ethereum Signed Message:\n" + nbytes + text`) before hashing and
signing. This is the digest behind Sign-In with Ethereum (SIWE) and most
“sign this message to log in” flows:

``` r

login <- "example.com wants you to sign in with your Ethereum account"
msig <- signer$sign_message(login)

as_hex(msig)
#> [1] "0x6b083a7d1440b7d3dd0f56bc30f725422f02e8365b7b9f4211b6cf04cb4635147e4becaa09d02c9c77bed3b139c4f06cf7fbf81dc645b61c8dde154870ba03991b"
```

A relying party verifies the login the same way – reconstruct the
prefixed digest and `ecrecover` the claimed address:

``` r

body <- charToRaw(enc2utf8(login))
prefix <- c(
  as.raw(0x19),
  charToRaw("Ethereum Signed Message:\n"),
  charToRaw(as.character(length(body)))
)
login_digest <- keccak256(c(prefix, body))

mrsv <- as_rsv(msig)
ecrecover(login_digest, mrsv$r, mrsv$s, mrsv$v) == signer$address
#> [1] TRUE
```

## Where to go next

- [`?EthSigner`](https://dereckscompany.github.io/ethsign/reference/EthSigner.md)
  for the full signer API (`$sign_digest`, `$sign_typed_data`,
  `$sign_message`).
- [`?eip712_digest`](https://dereckscompany.github.io/ethsign/reference/eip712_digest.md)
  for the typed-data digest details and field-type scope.
- [`?ecrecover`](https://dereckscompany.github.io/ethsign/reference/ecrecover.md)
  for signature verification.

The same primitives cover Hyperliquid user actions, Polymarket orders,
0x / CoW / 1inch / Seaport, ERC-2612 and Permit2 permits, Gnosis Safe,
Sign-In with Ethereum, and raw EVM transaction signing.
