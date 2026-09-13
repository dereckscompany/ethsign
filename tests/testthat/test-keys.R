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

# ---- item 4: EIP-55 checksum encoding ---------------------------------------
#
# The exact "All caps" / "All Lower" / "Normal" test vectors published in
# EIP-55 (https://github.com/ethereum/ercs/blob/master/ERCS/erc-55.md,
# "# Test Cases").

test_that("eth_checksum_address matches the EIP-55 spec test vectors", {
  # All caps
  expect_equal(
    eth_checksum_address("0x52908400098527886E0F7030069857D2E4169EE7"),
    "0x52908400098527886E0F7030069857D2E4169EE7"
  )
  expect_equal(
    eth_checksum_address("0x8617E340B3D01FA5F11F306F4090FD50E238070D"),
    "0x8617E340B3D01FA5F11F306F4090FD50E238070D"
  )
  # All lower
  expect_equal(
    eth_checksum_address("0xde709f2102306220921060314715629080e2fb77"),
    "0xde709f2102306220921060314715629080e2fb77"
  )
  expect_equal(
    eth_checksum_address("0x27b1fdb04752bbc536007a920d24acb045561c26"),
    "0x27b1fdb04752bbc536007a920d24acb045561c26"
  )
  # Normal (mixed case)
  expect_equal(
    eth_checksum_address("0x5aAeb6053F3E94C9b9A09f33669435E7Ef1BeAed"),
    "0x5aAeb6053F3E94C9b9A09f33669435E7Ef1BeAed"
  )
  expect_equal(
    eth_checksum_address("0xfB6916095ca1df60bB79Ce92cE3Ea74c37c5d359"),
    "0xfB6916095ca1df60bB79Ce92cE3Ea74c37c5d359"
  )
  expect_equal(
    eth_checksum_address("0xdbF03B407c01E7cD3CBea99509d93f8DDDC8C6FB"),
    "0xdbF03B407c01E7cD3CBea99509d93f8DDDC8C6FB"
  )
  expect_equal(
    eth_checksum_address("0xD1220A0cf47c7B9Be7A2E6BA89F429762e7b9aDb"),
    "0xD1220A0cf47c7B9Be7A2E6BA89F429762e7b9aDb"
  )
})

test_that("eth_checksum_address ignores the input's own casing and accepts a bare (no 0x) address", {
  addr <- "0x5aAeb6053F3E94C9b9A09f33669435E7Ef1BeAed"
  expect_equal(eth_checksum_address(tolower(addr)), addr)
  expect_equal(eth_checksum_address(toupper(addr)), addr)
  expect_equal(eth_checksum_address(sub("^0x", "", tolower(addr))), addr)
})

test_that("eth_checksum_address rejects a malformed address", {
  expect_error(eth_checksum_address("0x1234"), "40-hex")
  expect_error(eth_checksum_address("not an address"), "40-hex")
})
