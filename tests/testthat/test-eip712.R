# test-eip712.R
# EIP-712 structured-data hashing against the published spec vector.
#
# The canonical EIP-712 example (EIP-712, "Specification of the eth_signTypedData
# JSON RPC", the "Ether Mail" sample) publishes the domain separator for:
#   domain = { name: "Ether Mail", version: "1", chainId: 1,
#              verifyingContract: 0xCcCCccccCCCCcCCCCCCcCcCccCcCCCcCcccccccC }
# as 0xf2cee375fa42b42143804025fc449deafd50cc031ca257e0b194a650a912090f.

ether_mail_separator <-
  "f2cee375fa42b42143804025fc449deafd50cc031ca257e0b194a650a912090f"

test_that("the Ether Mail domain separator matches the EIP-712 spec vector", {
  sep <- ethsign:::eip712_domain_separator(
    name = "Ether Mail",
    version = "1",
    chain_id = 1,
    verifying_contract = "0xCcCCccccCCCCcCCCCCCcCcCccCcCCCcCcccccccC"
  )
  expect_true(is.raw(sep))
  expect_length(sep, 32L)
  expect_equal(paste(as.character(sep), collapse = ""), ether_mail_separator)
})

test_that("eip712_digest returns a deterministic raw(32) digest", {
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
  digest1 <- eip712_digest(domain, "Agent", types, message)
  digest2 <- eip712_digest(domain, "Agent", types, message)
  expect_true(is.raw(digest1))
  expect_length(digest1, 32L)
  expect_equal(digest1, digest2)
})

test_that("eip712_digest rejects a malformed domain", {
  bad_domain <- list(name = "Exchange")
  types <- list(list(name = "source", type = "string"))
  expect_error(
    eip712_digest(bad_domain, "Agent", types, list(source = "a")),
    "domain"
  )
})
