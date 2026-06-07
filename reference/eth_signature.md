# eth_signature: the canonical signature object

An S3 object of class `eth_signature` holding the `(r, s, v)` triple as
`r`/`s` 0x-hex strings and an integer recovery byte `v`. Referenced by
the
[EthSigner](https://dereckscompany.github.io/ethsign/reference/EthSigner.md)
signing methods and the
[`as_rsv()`](https://dereckscompany.github.io/ethsign/reference/as_rsv.md)
/
[`as_hex()`](https://dereckscompany.github.io/ethsign/reference/as_hex.md)
serializers.
