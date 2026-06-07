# test-keys.R
# Key normalisation and address derivation against a known external vector.
# The private key 0x0123...0123 derives address 0x14791697...308e59325 -- the
# canonical eth_account / Hyperliquid example key (used throughout their SDK
# tests), so this is an independent, externally-published vector.

known_key <- "0x0123456789012345678901234567890123456789012345678901234567890123"
known_address <- "0x14791697260e4c9a71f18484c9f997b308e59325"

test_that("eth_address derives the known address from the 0x0123... test key", {
  expect_equal(eth_address(known_key), known_address)
})

test_that("eth_address accepts a raw(32) key equivalently", {
  hex <- sub("^0x", "", known_key)
  starts <- seq(1L, 63L, by = 2L)
  key_raw <- as.raw(strtoi(substring(hex, starts, starts + 1L), 16L))
  expect_length(key_raw, 32L)
  expect_equal(eth_address(key_raw), known_address)
})

test_that("eth_keygen returns 0x + 64 hex that derives a clean address", {
  key <- eth_keygen()
  expect_match(key, "^0x[0-9a-f]{64}$")
  expect_match(eth_address(key), "^0x[0-9a-f]{40}$")
})

test_that("two eth_keygen draws differ (fresh randomness)", {
  expect_false(identical(eth_keygen(), eth_keygen()))
})

test_that("eth_address rejects malformed keys", {
  # Wrong-length hex string: caught by normalise_private_key's richer check.
  expect_error(eth_address("0x1234"), "64-character hex")
  # Wrong-length raw: caught by the type contract (raw must be length 32).
  expect_error(eth_address(as.raw(1:16)), "length 32")
})
