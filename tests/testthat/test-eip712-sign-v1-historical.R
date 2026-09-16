# test-eip712-sign-v1-historical.R
#
# HISTORICAL ONLY -- NOT AN ACCEPTANCE CRITERION FOR THIS PACKAGE.
#
# These are 0.1.0's original Polymarket vectors. They were generated from
# `py-clob-client` / `py_order_utils`, the client Polymarket ARCHIVED on
# 2026-05-25, and they describe the retired CTF Exchange **V1**:
#
#   * domain `version = "1"`, whereas `eip712Domain()` (EIP-5267, selector
#     0x84b0196e) on both live exchange contracts returned `version = "2"`
#     when read from Polygon on 2026-09-16;
#   * the retired V1 exchange addresses 0x4bFb...982E / 0xC5d5...f80a, neither
#     of which Polymarket routes orders to any more;
#   * a TWELVE-field `Order` struct (with `taker`, `expiration`, `nonce` and
#     `feeRateBps`), whereas ctf-exchange-v2's `Structs.sol` declares ELEVEN
#     fields (those four gone, `timestamp`/`metadata`/`builder` added).
#
# No signature produced under this domain can be accepted by any deployed
# Polymarket contract. Nothing here may be cited as evidence that ethsign
# signs Polymarket orders correctly -- test-eip712-sign.R is the file that
# does that, against the live V2 contracts.
#
# They are retained purely as regression coverage of the HASHING ENGINE: they
# exercise uint256 from a 77-digit decimal string, uint8, address padding, and
# a four-field domain, and their expected bytes are arithmetic facts about
# EIP-712 that do not expire with the contract they were taken from.

testkey <- "0xae6244eba76012e42c63632fd4b261fa3187490d282daeee64e4a30524639a3b"

# The V1 struct: twelve fields, as `py_order_utils/model/order.py` declared
# them. Superseded -- see the V2 list in test-eip712-sign.R.
v1_order_types <- list(
  list(name = "salt", type = "uint256"),
  list(name = "maker", type = "address"),
  list(name = "signer", type = "address"),
  list(name = "taker", type = "address"),
  list(name = "tokenId", type = "uint256"),
  list(name = "makerAmount", type = "uint256"),
  list(name = "takerAmount", type = "uint256"),
  list(name = "expiration", type = "uint256"),
  list(name = "nonce", type = "uint256"),
  list(name = "feeRateBps", type = "uint256"),
  list(name = "side", type = "uint8"),
  list(name = "signatureType", type = "uint8")
)

v1_order_message <- list(
  salt = 12345,
  maker = "0xaeFB910F214a73FB595Efb5CB28c3e332914bF05",
  signer = "0xaeFB910F214a73FB595Efb5CB28c3e332914bF05",
  taker = "0x0000000000000000000000000000000000000000",
  tokenId = "13074185296307418529630741852963074185296307418529630741852963074185296307418",
  makerAmount = 1000000,
  takerAmount = 1000000,
  expiration = 0,
  nonce = 0,
  feeRateBps = 0,
  side = 0,
  signatureType = 0
)

test_that("[historical V1, not live] the archived client's standard-exchange signature still reproduces", {
  domain <- list(
    name = "Polymarket CTF Exchange",
    version = "1", # retired: the live contracts report "2"
    chainId = 137,
    verifyingContract = "0x4bFb41d5B3570DeFd03C39a9A4D8dE6Bd8B8982E" # retired V1 exchange
  )
  sig <- eip712_sign(eth_signer(testkey), domain, v1_order_types, "Order", v1_order_message)
  expect_equal(
    sig,
    paste0(
      "0x3e459c207244a8b6e95224a8277bd2ce028c7246fdace111340a235fb304c4a",
      "a572e9ff30c9680de3fab18f2f806c26bf5711e8f9f44f93469a7b7a7acbd38c71c"
    )
  )
})

test_that("[historical V1, not live] the archived client's neg-risk-exchange signature still reproduces", {
  domain <- list(
    name = "Polymarket CTF Exchange",
    version = "1", # retired: the live contracts report "2"
    chainId = 137,
    verifyingContract = "0xC5d563A36AE78145C45a50134d48A1215220f80a" # retired V1 neg-risk exchange
  )
  sig <- eip712_sign(eth_signer(testkey), domain, v1_order_types, "Order", v1_order_message)
  expect_equal(
    sig,
    paste0(
      "0x9455237fa43d90d6ad3c7cd3dd15b86cae16ac6915255bb45c701efa84e4809",
      "f3716b3b4f5e8bf02abbfaad3a3e20346362d655ec90c18d6b75a620fceed39031c"
    )
  )
})
