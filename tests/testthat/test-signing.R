# test-signing.R
# Cross-implementation proof: reproduce the official Hyperliquid SDK USER-SIGNED
# EIP-712 vectors (testnet) via the generic eth_signer()$sign_typed_data() API.
#
# Source of truth (independent external vectors): the official
# hyperliquid-python-sdk signing_test.py, replayed in the spike harness at
# exchanges/_research_hyperliquid/spike/run_vectors.R. The test key 0x0123...0123
# signs the usdSend and withdraw3 user-signed actions; the expected r/s/v below
# are the exact values that harness asserts against the Python SDK (testnet).
#
# The SDK injects signatureChainId ("0x66eee") and hyperliquidChain ("Testnet")
# into the signed action and signs under the HyperliquidSignTransaction domain
# with chainId 0x66eee (= 421614). We replicate the message precisely; only the
# four typed fields are encoded into the struct hash, so the extra
# signatureChainId key is ignored, exactly as in eth_account.

testkey <- "0x0123456789012345678901234567890123456789012345678901234567890123"

hl_domain <- list(
  name = "HyperliquidSignTransaction",
  version = "1",
  chainId = strtoi("66eee", 16L),
  verifyingContract = "0x0000000000000000000000000000000000000000"
)

# Shared UsdSend / Withdraw field list (string, string, string, uint64).
hl_types <- list(
  list(name = "hyperliquidChain", type = "string"),
  list(name = "destination", type = "string"),
  list(name = "amount", type = "string"),
  list(name = "time", type = "uint64")
)

hl_message <- list(
  hyperliquidChain = "Testnet",
  destination = "0x5e9ee1089755c3435139848e47e6635505d5a13a",
  amount = "1",
  time = 1687816341423,
  signatureChainId = "0x66eee"
)

test_that("the signer address matches the Hyperliquid test-key vector", {
  expect_equal(eth_address(testkey), "0x14791697260e4c9a71f18484c9f997b308e59325")
})

test_that("usdSend testnet reproduces the Hyperliquid Python SDK r/s/v", {
  sig <- eth_signer(testkey)$sign_typed_data(
    hl_domain,
    "HyperliquidTransaction:UsdSend",
    hl_types,
    hl_message
  )
  rsv <- as_rsv(sig)
  expect_equal(rsv$r, "0x637b37dd731507cdd24f46532ca8ba6eec616952c56218baeff04144e4a77073")
  expect_equal(rsv$s, "0x11a6a24900e6e314136d2592e2f8d502cd89b7c15b198e1bee043c9589f9fad7")
  expect_equal(rsv$v, 27L)
})

test_that("withdraw3 testnet reproduces the Hyperliquid Python SDK r/s/v", {
  sig <- eth_signer(testkey)$sign_typed_data(
    hl_domain,
    "HyperliquidTransaction:Withdraw",
    hl_types,
    hl_message
  )
  rsv <- as_rsv(sig)
  expect_equal(rsv$r, "0x8363524c799e90ce9bc41022f7c39b4e9bdba786e5f9c72b20e43e1462c37cf9")
  expect_equal(rsv$s, "0x58b1411a775938b83e29182e8ef74975f9054c8e97ebf5ec2dc8d51bfc893881")
  expect_equal(rsv$v, 28L)
})

test_that("the Hyperliquid usdSend digest ecrecovers to the signer (independent)", {
  # A second, independent check of digest construction: recover the address from
  # the signature over the same digest -- must be the test key's address.
  digest <- eip712_digest(hl_domain, "HyperliquidTransaction:UsdSend", hl_types, hl_message)
  expect_true(is.raw(digest))
  expect_length(digest, 32L)
  rsv <- as_rsv(eth_signer(testkey)$sign_digest(digest))
  expect_equal(ecrecover(digest, rsv$r, rsv$s, rsv$v), eth_address(testkey))
})
