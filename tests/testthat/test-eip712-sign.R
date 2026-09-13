# test-eip712-sign.R
# eip712_sign() (item 6: a general signer returning the 65-byte r||s||v hex
# form) against real Polymarket CLOB vectors, cross-checked against the
# OFFICIAL python client rather than merely round-tripping through ethsign's
# own code.
#
# Provenance: vectors generated in a scratch venv --
#   python3 -m venv pyclob && pip install py-clob-client
#   (py_clob_client 0.34.6, py_order_utils 0.3.2, poly_eip712_structs 0.0.1,
#   eth_account 0.14.0)
# -- by constructing the same objects the SDK itself uses:
#   * `py_order_utils.builders.OrderBuilder` for the `Order` struct (the
#     "Polymarket CTF Exchange" domain, chain 137, and the standard vs.
#     neg-risk exchange contract addresses from `py_clob_client.config`).
#   * `py_clob_client.signing.model.ClobAuth` / `eip712.get_clob_auth_domain`
#     for the login message (the "ClobAuthDomain" domain: name, version,
#     chainId only -- NO verifyingContract, item 2's three-field-domain case).
# All three were signed there with a fresh THROWAWAY private key generated in
# that same script (never used anywhere else, unfunded); the key, the exact
# generation script (gen_vectors.py), and its raw stdout are not committed,
# only the resulting domain/types/message/signature vectors below.

testkey <- "0xae6244eba76012e42c63632fd4b261fa3187490d282daeee64e4a30524639a3b"
address <- "0xaefb910f214a73fb595efb5cb28c3e332914bf05" # eth_address() is lowercase

test_that("the throwaway signer address matches the python client's Account.from_key() address", {
  expect_equal(eth_address(testkey), address)
})

# ---- Order struct: field order and types exactly as py_order_utils'
# `Order(EIP712Struct)` declares them (salt, maker, signer, taker, tokenId,
# makerAmount, takerAmount, expiration, nonce, feeRateBps, side,
# signatureType) -- see py_order_utils/model/order.py.

order_types <- list(
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

# A 77-digit synthetic CTF token id (item 3: decimal-string uintN input, far
# past the 2^53 double-precision limit) -- real conditional-token ids run to
# exactly this many digits.
big_token_id <- "13074185296307418529630741852963074185296307418529630741852963074185296307418"

order_message <- list(
  salt = 12345,
  maker = "0xaeFB910F214a73FB595Efb5CB28c3e332914bF05",
  signer = "0xaeFB910F214a73FB595Efb5CB28c3e332914bF05",
  taker = "0x0000000000000000000000000000000000000000",
  tokenId = big_token_id,
  makerAmount = 1000000,
  takerAmount = 1000000,
  expiration = 0,
  nonce = 0,
  feeRateBps = 0,
  side = 0,
  signatureType = 0
)

test_that("eip712_sign reproduces py_order_utils' Order signature on the standard CTF Exchange", {
  domain <- list(
    name = "Polymarket CTF Exchange",
    version = "1",
    chainId = 137,
    verifyingContract = "0x4bFb41d5B3570DeFd03C39a9A4D8dE6Bd8B8982E" # config.py CONFIG[137].exchange
  )
  sig <- eip712_sign(eth_signer(testkey), domain, order_types, "Order", order_message)
  expect_match(sig, "^0x[0-9a-f]{130}$")
  expect_equal(
    sig,
    paste0(
      "0x3e459c207244a8b6e95224a8277bd2ce028c7246fdace111340a235fb304c4a",
      "a572e9ff30c9680de3fab18f2f806c26bf5711e8f9f44f93469a7b7a7acbd38c71c"
    )
  )
})

test_that("eip712_sign reproduces py_order_utils' Order signature on the neg-risk CTF Exchange", {
  # Same order fields, only `verifyingContract` differs -- item 2's whole
  # point: a wrong (e.g. zero-padded or swapped) verifyingContract gives a
  # different, wrong signature. This is the independent proof it does not.
  domain <- list(
    name = "Polymarket CTF Exchange",
    version = "1",
    chainId = 137,
    verifyingContract = "0xC5d563A36AE78145C45a50134d48A1215220f80a" # config.py NEG_RISK_CONFIG[137].exchange
  )
  sig <- eip712_sign(eth_signer(testkey), domain, order_types, "Order", order_message)
  expect_match(sig, "^0x[0-9a-f]{130}$")
  expect_equal(
    sig,
    paste0(
      "0x9455237fa43d90d6ad3c7cd3dd15b86cae16ac6915255bb45c701efa84e4809",
      "f3716b3b4f5e8bf02abbfaad3a3e20346362d655ec90c18d6b75a620fceed39031c"
    )
  )
  std_sig <- eip712_sign(
    eth_signer(testkey),
    list(
      name = "Polymarket CTF Exchange",
      version = "1",
      chainId = 137,
      verifyingContract = "0x4bFb41d5B3570DeFd03C39a9A4D8dE6Bd8B8982E"
    ),
    order_types,
    "Order",
    order_message
  )
  expect_false(identical(sig, std_sig))
})

# ---- ClobAuth: the three-field domain (item 2) -- name, version, chainId,
# NO verifyingContract -- see py_clob_client/signing/{model,eip712}.py.

test_that("eip712_digest reproduces py-clob-client's ClobAuth digest under a three-field domain", {
  clob_domain <- list(name = "ClobAuthDomain", version = "1", chainId = 137)
  clob_types <- list(
    list(name = "address", type = "address"),
    list(name = "timestamp", type = "string"),
    list(name = "nonce", type = "uint256"),
    list(name = "message", type = "string")
  )
  clob_message <- list(
    address = "0xaeFB910F214a73FB595Efb5CB28c3e332914bF05",
    timestamp = "1000000000",
    nonce = 0,
    message = "This message attests that I control the given wallet"
  )
  digest <- eip712_digest(clob_domain, "ClobAuth", clob_types, clob_message)
  expect_equal(
    paste(as.character(digest), collapse = ""),
    "f3979e44a2ad5012b2278bbda451ae50679f249584bcd69b4879b8dd8129a392"
  )
  sig <- eip712_sign(eth_signer(testkey), clob_domain, clob_types, "ClobAuth", clob_message)
  expect_equal(
    sig,
    paste0(
      "0x4e1c9c61dc708fc93bd36638e7f8a31a280ac58a53751b96220efe4f9b21bda",
      "c7dacbed661f93202c1a435b3713eaabc3a783172e6ab4784796388003d8e6cd21c"
    )
  )
})

test_that("eip712_sign's digest ecrecovers to the throwaway signer (independent of the pinned bytes)", {
  clob_domain <- list(name = "ClobAuthDomain", version = "1", chainId = 137)
  clob_types <- list(
    list(name = "address", type = "address"),
    list(name = "timestamp", type = "string"),
    list(name = "nonce", type = "uint256"),
    list(name = "message", type = "string")
  )
  clob_message <- list(
    address = "0xaeFB910F214a73FB595Efb5CB28c3e332914bF05",
    timestamp = "1000000000",
    nonce = 0,
    message = "This message attests that I control the given wallet"
  )
  digest <- eip712_digest(clob_domain, "ClobAuth", clob_types, clob_message)
  sig <- as_hex(eth_signer(testkey)$sign_digest(digest))
  r <- paste0("0x", substr(sig, 3L, 66L))
  s <- paste0("0x", substr(sig, 67L, 130L))
  v <- strtoi(substr(sig, 131L, 132L), 16L)
  expect_equal(ecrecover(digest, r, s, v), address)
})
