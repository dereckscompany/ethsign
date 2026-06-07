# test-sign-message.R
# EIP-191 personal_sign ($sign_message) round-trips through ecrecover back to the
# signer address. We rebuild the EIP-191 prefixed digest independently here
# ("\x19Ethereum Signed Message:\n" + nbytes + text) and recover against it, so
# the test does not merely re-call the signer's own internal digest.

eip191_digest <- function(text) {
  body <- charToRaw(enc2utf8(text))
  prefix <- c(
    as.raw(0x19),
    charToRaw("Ethereum Signed Message:\n"),
    charToRaw(as.character(length(body)))
  )
  return(keccak256(c(prefix, body)))
}

test_that("sign_message round-trips via ecrecover to the signer address", {
  signer <- eth_signer_random()
  messages <- c("gm", "Sign in with Ethereum", "", "unicode: éè")
  for (text in messages) {
    rsv <- as_rsv(signer$sign_message(text))
    recovered <- ecrecover(eip191_digest(text), rsv$r, rsv$s, rsv$v)
    expect_equal(recovered, signer$address)
  }
})

test_that("sign_message is deterministic (RFC 6979) for a fixed key", {
  signer <- eth_signer(
    "0x0123456789012345678901234567890123456789012345678901234567890123"
  )
  expect_equal(as_hex(signer$sign_message("gm")), as_hex(signer$sign_message("gm")))
})

test_that("sign_message rejects non-scalar-character input (contract)", {
  signer <- eth_signer_random()
  expect_error(signer$sign_message(c("a", "b")), "single character")
})
