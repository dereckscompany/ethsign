# test-keccak.R
# Keccak-256 against independent, externally-published vectors. Ethereum uses
# the ORIGINAL (pre-FIPS-202) Keccak, NOT SHA3-256, so these are the canonical
# Ethereum Keccak-256 vectors (a SHA3-256 implementation would give different
# digests, e.g. SHA3-256("") = a7ffc6f8...).

keccak_hex <- function(x) {
  return(paste(as.character(keccak256(x)), collapse = ""))
}

test_that("keccak256 of the empty string matches the Ethereum vector", {
  # Canonical Ethereum keccak256("") -- the same value the package's load-time
  # self-test pins, and the value Solidity's keccak256("") returns.
  expect_equal(
    keccak_hex(""),
    "c5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470"
  )
})

test_that("keccak256 of \"abc\" matches the Ethereum Keccak-256 vector", {
  # Canonical Keccak-256 of "abc" (original Keccak, not SHA3-256). Pinned from
  # this implementation and cross-checked against the well-known public
  # Keccak-256("abc") test vector.
  expect_equal(
    keccak_hex("abc"),
    "4e03657aea45a94fc7d47ba826c8d667c0d1e6e33a64a036ec44f58fa12d6c45"
  )
})

test_that("keccak256 accepts raw input and returns plain raw(32)", {
  out <- keccak256(as.raw(c(0x12, 0x34)))
  expect_true(is.raw(out))
  expect_length(out, 32L)
  expect_false(inherits(out, "hash"))
})

test_that("keccak256 hashing of a string equals hashing its UTF-8 bytes", {
  expect_equal(keccak256("abc"), keccak256(charToRaw("abc")))
})

test_that("keccak256 rejects non-raw, non-scalar-character input (contract)", {
  expect_error(keccak256(123), "at least one of")
  expect_error(keccak256(c("a", "b")), "at least one of")
})
