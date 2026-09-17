# test-conditions.R
# Typed conditions for ethsign's 27 error sites (R/conditions.R). Internal
# (unexported) functions and raisers are reached via ethsign:::fn. Each test
# below drives an actual abort site (not just the raiser in isolation), so a
# regression that reroutes a site to the wrong kind is caught here.

# ---- validation ----------------------------------------------------------

test_that("a real validation site raises a classed, root-inheriting ethsign_validation_error", {
  err <- expect_error(eth_checksum_address("0x1234"), class = "ethsign_validation_error")
  expect_s3_class(err, "ethsign_error")
  expect_match(conditionMessage(err), "40-hex")
})

# ---- encoding --------------------------------------------------------------

test_that("a real encoding site raises a classed, root-inheriting ethsign_encoding_error", {
  err <- expect_error(
    ethsign:::eip712_encode_value("uint8", 256),
    class = "ethsign_encoding_error"
  )
  expect_s3_class(err, "ethsign_error")
  expect_match(conditionMessage(err), "out of range")
})

# ---- signing ---------------------------------------------------------------
# r == 0 / s == 0 are astronomically unlikely (~2^-128) for any real digest and
# key, so ec_mul is mocked to force each branch directly rather than searching
# for a colliding input.

test_that("the real r == 0 signing site raises a classed, root-inheriting ethsign_signing_error", {
  testthat::local_mocked_bindings(
    ec_mul = function(k, P) list(x = gmp::as.bigz(0), y = gmp::as.bigz(1)),
    .package = "ethsign"
  )
  digest32 <- ethsign:::bigz2raw32(gmp::as.bigz(123))
  priv32 <- ethsign:::bigz2raw32(gmp::as.bigz(1))
  err <- expect_error(
    ethsign:::ecdsa_sign_rfc6979(digest32, priv32),
    class = "ethsign_signing_error"
  )
  expect_s3_class(err, "ethsign_error")
  expect_match(conditionMessage(err), "r == 0")
})

test_that("the real s == 0 signing site raises a classed, root-inheriting ethsign_signing_error", {
  n <- ethsign:::secp256k1_n
  d <- gmp::as.bigz(1)
  r <- gmp::as.bigz(5)
  z <- n - r * d # forces (z + r * d) %% n == 0, i.e. s == 0, whatever k is
  testthat::local_mocked_bindings(
    ec_mul = function(k, P) list(x = r, y = gmp::as.bigz(1)),
    .package = "ethsign"
  )
  digest32 <- ethsign:::bigz2raw32(z)
  priv32 <- ethsign:::bigz2raw32(d)
  err <- expect_error(
    ethsign:::ecdsa_sign_rfc6979(digest32, priv32),
    class = "ethsign_signing_error"
  )
  expect_s3_class(err, "ethsign_error")
  expect_match(conditionMessage(err), "s == 0")
})

# ---- integrity ---------------------------------------------------------------
# The self-test only fails when the Keccak-256 primitive itself is wrong, which
# never happens in a healthy install, so keccak256_hex is mocked to force it.

test_that("the real load-time self-test site raises a classed, root-inheriting ethsign_integrity_error", {
  testthat::local_mocked_bindings(
    keccak256_hex = function(x) "not-the-right-digest",
    .package = "ethsign"
  )
  err <- expect_error(
    ethsign:::keccak256_self_test(),
    class = "ethsign_integrity_error"
  )
  expect_s3_class(err, "ethsign_error")
  expect_match(conditionMessage(err), "self-test FAILED")
})

# ---- the four raisers agree on the shared domain root -----------------------

test_that("the four raisers layer their subclass then the ethsign_error domain root", {
  ev <- tryCatch(ethsign:::abort_ethsign_validation_error("v"), error = function(e) e)
  expect_identical(
    class(ev),
    c("ethsign_validation_error", "ethsign_error", "rlang_error", "error", "condition")
  )
  ee <- tryCatch(ethsign:::abort_ethsign_encoding_error("e"), error = function(e) e)
  expect_identical(
    class(ee),
    c("ethsign_encoding_error", "ethsign_error", "rlang_error", "error", "condition")
  )
  es <- tryCatch(ethsign:::abort_ethsign_signing_error("s"), error = function(e) e)
  expect_identical(
    class(es),
    c("ethsign_signing_error", "ethsign_error", "rlang_error", "error", "condition")
  )
  ei <- tryCatch(ethsign:::abort_ethsign_integrity_error("i"), error = function(e) e)
  expect_identical(
    class(ei),
    c("ethsign_integrity_error", "ethsign_error", "rlang_error", "error", "condition")
  )
})
