# Compute an EIP-712 Typed-Data Signing Digest

Hashes a single EIP-712 struct under its domain and returns the
`0x1901`-prefixed digest ready to sign (the value an
[EthSigner](https://dereckscompany.github.io/ethsign/reference/EthSigner.md)
passes to `$sign_digest()`). This is the standard typed-data digest used
by EVM venues such as Hyperliquid and Polymarket.

## Usage

``` r
eip712_digest(domain, primary_type, types, message)
```

## Arguments

- domain:

  (list) the EIP-712 domain, with `name` (character), `version`
  (character), `chainId` (numeric or
  [`gmp::bigz`](https://rdrr.io/pkg/gmp/man/biginteger.html)), and
  `verifyingContract` (a `0x`-prefixed 20-byte address).

- primary_type:

  (scalar\<character\>) the struct name, e.g. `"Order"`.

- types:

  (list) the ordered field list for `primary_type`, each element a
  `list(name = <chr>, type = <chr>)` in definition order.

- message:

  (list) field values, looked up by field name.

## Value

(vector\<raw, 32\>) the signing digest.

## Details

Scope: a single struct over atomic field types (`string`, `uint64`,
`uint256`, `bool`, `address`, `bytes32`). Nested struct types and arrays
are out of scope for v0.

## Examples

``` r
domain <- list(
  name = "Exchange",
  version = "1",
  chainId = 1337,
  verifyingContract = "0x0000000000000000000000000000000000000000"
)
types <- list(
  list(name = "source", type = "string"),
  list(name = "connectionId", type = "bytes32")
)
message <- list(source = "a", connectionId = keccak256("hello"))
eip712_digest(domain, "Agent", types, message)
#>  [1] 8a 0b 82 ce 65 fc 7b 04 cb 32 50 fe 83 b7 a3 d1 6c 71 3e 34 4c 7c 7f 08 c8
#> [26] 2b 5c 74 5f 70 49 1a
```
