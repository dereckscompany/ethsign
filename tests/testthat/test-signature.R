# test-signature.R
# The signature object and its two wire serialisers, plus the ecrecover
# round-trip (an independent inverse check: recover() . sign() == identity on the
# signer address) over several fresh random keys.

test_that("as_hex is 0x + 130 hex with a 1b/1c recovery byte", {
  sig <- eth_signer_random()$sign_message("serialize me")
  hex <- as_hex(sig)
  expect_match(hex, "^0x[0-9a-f]{130}$")
  expect_true(substr(hex, 131L, 132L) %in% c("1b", "1c"))
})

test_that("as_rsv projects to r/s/v with 0x-hex r/s and integer v in {27,28}", {
  sig <- eth_signer_random()$sign_message("project me")
  rsv <- as_rsv(sig)
  expect_named(rsv, c("r", "s", "v"))
  expect_match(rsv$r, "^0x[0-9a-f]+$")
  expect_match(rsv$s, "^0x[0-9a-f]+$")
  expect_true(rsv$v %in% c(27L, 28L))
})

test_that("ecrecover recovers the signer for several random signatures", {
  for (i in seq_len(8L)) {
    signer <- eth_signer_random()
    digest <- keccak256(paste0("round-trip ", i))
    rsv <- as_rsv(signer$sign_digest(digest))
    expect_equal(ecrecover(digest, rsv$r, rsv$s, rsv$v), signer$address)
  }
})

test_that("ecrecover with the wrong digest does not recover the signer", {
  signer <- eth_signer_random()
  rsv <- as_rsv(signer$sign_digest(keccak256("the real message")))
  recovered <- ecrecover(keccak256("a different message"), rsv$r, rsv$s, rsv$v)
  expect_false(identical(recovered, signer$address))
})

test_that("the serialisers reject anything that is not an eth_signature", {
  expect_error(as_hex(list(r = "0x1", s = "0x2", v = 27L)), "eth_signature")
  expect_error(as_rsv("not a signature"), "eth_signature")
})
