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
  sep <- ethsign:::eip712_domain_separator(list(
    name = "Ether Mail",
    version = "1",
    chainId = 1,
    verifyingContract = "0xCcCCccccCCCCcCCCCCCcCcCccCcCCCcCcccccccC"
  ))
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

test_that("eip712_digest accepts a partial domain (only the keys present are hashed)", {
  # A single-field domain is valid EIP-712 (item 2): the four-key requirement
  # is dropped so venues such as Polymarket's ClobAuth (name/version/chainId,
  # no verifyingContract) work. Regression: this must NOT error.
  partial_domain <- list(name = "Exchange")
  types <- list(list(name = "source", type = "string"))
  digest <- eip712_digest(partial_domain, "Agent", types, list(source = "a"))
  expect_true(is.raw(digest))
  expect_length(digest, 32L)
})

test_that("eip712_digest rejects an unknown domain field", {
  bad_domain <- list(name = "Exchange", notAField = "x")
  types <- list(list(name = "source", type = "string"))
  expect_error(
    eip712_digest(bad_domain, "Agent", types, list(source = "a")),
    "domain"
  )
})

test_that("eip712_digest rejects an empty domain", {
  types <- list(list(name = "source", type = "string"))
  expect_error(
    eip712_digest(list(), "Agent", types, list(source = "a")),
    "domain"
  )
})

# ---- item 1: the full uintN family (N a multiple of 8 in 8..256) -----------
#
# Each width is checked against its exact big-endian 32-byte encoding -- the
# definition itself, not merely a round-trip through our own code. The
# uint256-max vector (2^256 - 1, the all-0xff case) is independently derived
# from `2**256 - 1` in plain arithmetic, not from this package.

hex_pairs <- function(h) {
  starts <- seq(1L, nchar(h) - 1L, by = 2L)
  return(vapply(starts, function(i) substr(h, i, i + 1L), character(1)))
}

test_that("eip712_encode_value handles the full uintN family", {
  expect_equal(
    as.character(ethsign:::eip712_encode_value("uint8", 255)),
    c(rep("00", 31L), "ff")
  )
  expect_equal(
    as.character(ethsign:::eip712_encode_value("uint16", 65535)),
    c(rep("00", 30L), "ff", "ff")
  )
  expect_equal(
    as.character(ethsign:::eip712_encode_value("uint128", 1)),
    c(rep("00", 31L), "01")
  )
  max_u256 <- "115792089237316195423570985008687907853269984665640564039457584007913129639935"
  expect_equal(
    as.character(ethsign:::eip712_encode_value("uint256", max_u256)),
    rep("ff", 32L)
  )
  expect_equal(
    as.character(ethsign:::eip712_encode_value("uint256", 0)),
    rep("00", 32L)
  )
})

test_that("eip712_encode_value rejects out-of-range values and malformed uintN widths", {
  expect_error(ethsign:::eip712_encode_value("uint8", 256), "out of range")
  expect_error(ethsign:::eip712_encode_value("uint8", -1), "out of range")
  expect_error(ethsign:::eip712_encode_value("uint7", 1), "unsupported field type")
  expect_error(ethsign:::eip712_encode_value("uint264", 1), "unsupported field type")
})

# ---- item 3: big-integer safety --------------------------------------------
#
# A plain R double is only exact up to 2^53; a numeric above that must abort
# rather than silently sign the wrong (rounded) value. Decimal and 0x-hex
# strings are the escape hatch for larger values (e.g. Polymarket's 77-digit
# conditional-token ids -- see test-eip712-sign.R). ethsign depends on `gmp`
# already, so this goes through `gmp::as.bigz()` rather than a base-R
# decimal-string parser (the spec's fallback only applies with no bignum
# dependency).

test_that("a numeric uintN value above 2^53 aborts, but exactly 2^53 does not", {
  expect_error(
    ethsign:::eip712_encode_value("uint256", 2^53 + 1024),
    "cannot be represented exactly"
  )
  expect_equal(
    ethsign:::eip712_encode_value("uint256", 2^53),
    ethsign:::eip712_encode_value("uint256", "9007199254740992")
  )
})

test_that("a 77-digit decimal string and its 0x-hex form encode identically to an independently-derived vector", {
  # The decimal value and its hex form below were both derived independently
  # via Python's arbitrary-precision int (`format(n, "x")`), not via this
  # package's own gmp usage.
  decimal <- "13074185296307418529630741852963074185296307418529630741852963074185296307418"
  hex <- "0x1ce7ba0529b4285829f9c3d586278bf3f8f8e1863393f68995d6bba50edf64da"
  expected <- hex_pairs("1ce7ba0529b4285829f9c3d586278bf3f8f8e1863393f68995d6bba50edf64da")
  expect_equal(as.character(ethsign:::eip712_encode_value("uint256", decimal)), expected)
  expect_equal(as.character(ethsign:::eip712_encode_value("uint256", hex)), expected)
})

test_that("a gmp::bigz uintN value is accepted directly", {
  expect_equal(
    ethsign:::eip712_encode_value("uint256", gmp::as.bigz(42)),
    ethsign:::eip712_encode_value("uint256", 42)
  )
})

# ---- item 5: one-level nested struct support -------------------------------

test_that("eip712_digest reproduces the EIP-712 spec's own nested-struct (Mail/Person) vector", {
  # The exact JSON payload published in the EIP-712 spec's eth_signTypedData
  # curl example ("Ether Mail", https://eips.ethereum.org/EIPS/eip-712):
  # a Mail struct whose `from`/`to` fields are each a nested Person struct.
  # The expected digest below was computed independently via eth_account
  # (`encode_typed_data()` + `_hash_eip191_message()`), not via ethsign.
  types <- list(
    Person = list(
      list(name = "name", type = "string"),
      list(name = "wallet", type = "address")
    ),
    Mail = list(
      list(name = "from", type = "Person"),
      list(name = "to", type = "Person"),
      list(name = "contents", type = "string")
    )
  )
  domain <- list(
    name = "Ether Mail",
    version = "1",
    chainId = 1,
    verifyingContract = "0xCcCCccccCCCCcCCCCCCcCcCccCcCCCcCcccccccC"
  )
  message <- list(
    from = list(name = "Cow", wallet = "0xCD2a3d9F938E13CD947Ec05AbC7FE734Df8DD826"),
    to = list(name = "Bob", wallet = "0xbBbBBBBbbBBBbbbBbbBbbbbBBbBbbbbBbBbbBBbB"),
    contents = "Hello, Bob!"
  )
  digest <- eip712_digest(domain, "Mail", types, message)
  expect_equal(
    paste(as.character(digest), collapse = ""),
    "be609aee343fb3c4b28e1df9e632fca64fcfaede20f02e86244efddf30957bd2"
  )
})

test_that("eip712_encode_type appends referenced struct definitions alphabetically", {
  types <- list(
    Person = list(
      list(name = "wallet", type = "address"),
      list(name = "name", type = "string")
    ),
    Mail = list(
      list(name = "from", type = "Person"),
      list(name = "to", type = "Person"),
      list(name = "contents", type = "string")
    )
  )
  expect_equal(
    ethsign:::eip712_encode_type("Mail", types),
    paste0(
      "Mail(Person from,Person to,string contents)",
      "Person(address wallet,string name)"
    )
  )
})
