# test-eip712-sign.R
# ACCEPTANCE vectors: eip712_sign() / eip712_digest() against the CTF Exchange
# **V2** contracts that Polymarket actually runs today, cross-checked against
# the OFFICIAL python client AND against the deployed contracts themselves --
# never merely round-tripped through ethsign's own code.
#
# Why this file was rewritten for 0.2.0
# ------------------------------------
# 0.1.0's vectors came from `py-clob-client`, which Polymarket ARCHIVED on
# 2026-05-25. They pin `version = "1"` and the retired V1 exchange addresses.
# Reading `eip712Domain()` (EIP-5267, selector 0x84b0196e) on the live
# contracts on 2026-09-16 returns `version = "2"`, so the 0.1.0 vectors
# describe a domain no deployed contract will ever accept. They are kept, for
# hashing-engine regression only, in test-eip712-sign-v1-historical.R and are
# NOT acceptance criteria for this package. THIS file is.
#
# Provenance of every byte below
# ------------------------------
# Ground-truth commits (read 2026-09-16):
#   Polymarket/ctf-exchange-v2    ccc0596074f4dfd62c944fbca4de252893b82b4b
#   Polymarket/py-clob-client-v2  215fc63a8fd6ec3a10c7edb73997c9772d8686d3
#   Polymarket/py-sdk             579bb2e56be9cc5d152546985870ee6ad795ec52
#
# Generated in a scratch venv with a THROWAWAY key (below), by driving the
# official client's own builder rather than reimplementing it:
#   python3 -m venv venv
#   ./venv/bin/pip install eth-account eth-abi eth-utils
#   ./venv/bin/pip install ./py-clob-client-v2     # the commit above
#   ./venv/bin/python gen_vectors.py
# Package versions in that venv: py-clob-client-v2 1.1.0, eth-account 0.14.0,
# eth-abi 6.0.0, eth-utils 6.0.0.
#
# `gen_vectors.py` builds `ExchangeOrderBuilderV2(contract_address, 137,
# Signer(TESTKEY))` with a pinned salt and timestamp, then takes
# `build_signed_order()` / `build_order_hash()`. The ClobAuth vector uses the
# three-field `ClobAuthDomain` (name, version, chainId -- NO
# verifyingContract), matching py-sdk's `_internal/l1_auth.py`.
#
# Independent confirmation (not from any client): each `digest` below was also
# obtained by calling `hashOrder(Order)` on the DEPLOYED exchange over a
# keyless Polygon RPC, with the same field values. Contract and client agree
# byte for byte, so these vectors are anchored to the chain, not to an SDK.

# THROWAWAY key: generated for vectors only, unfunded, never used anywhere
# else, and deliberately committed so the vectors are reproducible.
testkey <- "0xae6244eba76012e42c63632fd4b261fa3187490d282daeee64e4a30524639a3b"
address <- "0xaefb910f214a73fb595efb5cb28c3e332914bf05" # eth_address() is lowercase

test_that("the throwaway signer address matches the python client's Account.from_key() address", {
  expect_equal(eth_address(testkey), address)
})

# ---- The V2 `Order` struct ---------------------------------------------------
# Field order and types exactly as the CONTRACT declares them in
# ctf-exchange-v2's `Structs.sol` (`ORDER_TYPEHASH`'s own type string) and as
# both python clients mirror them
# (`py_clob_client_v2/order_utils/model/ctf_exchange_v2_typed_data.py`,
# `py-sdk/_internal/actions/orders/typed_data.py`). ELEVEN fields:
#   salt, maker, signer, tokenId, makerAmount, takerAmount, side,
#   signatureType, timestamp, metadata, builder
# There is NO `taker`, NO `expiration`, NO `nonce` and NO `feeRateBps` in V2:
# those four were V1 fields. `expiration` still travels in the POST /order
# wire body, but it is not signed over.

order_types <- list(
  list(name = "salt", type = "uint256"),
  list(name = "maker", type = "address"),
  list(name = "signer", type = "address"),
  list(name = "tokenId", type = "uint256"),
  list(name = "makerAmount", type = "uint256"),
  list(name = "takerAmount", type = "uint256"),
  list(name = "side", type = "uint8"),
  list(name = "signatureType", type = "uint8"),
  list(name = "timestamp", type = "uint256"),
  list(name = "metadata", type = "bytes32"),
  list(name = "builder", type = "bytes32")
)

# A 77-digit synthetic CTF token id: a decimal-string uintN input far past the
# 2^53 double-precision limit, exactly as real conditional-token ids are.
big_token_id <- "13074185296307418529630741852963074185296307418529630741852963074185296307418"

order_message <- list(
  salt = 12345,
  maker = "0xaeFB910F214a73FB595Efb5CB28c3e332914bF05",
  signer = "0xaeFB910F214a73FB595Efb5CB28c3e332914bF05",
  tokenId = big_token_id,
  makerAmount = 1000000,
  takerAmount = 1000000,
  side = 0,
  signatureType = 0,
  timestamp = "1750000000000", # unix MILLIseconds -- V2 signs ms, not seconds
  metadata = raw(32), # bytes32 zero, the client's own default
  builder = raw(32) # bytes32 zero, the client's own default
)

test_that("the V2 Order type string hashes to the contract's own ORDER_TYPEHASH", {
  # Structs.sol pins ORDER_TYPEHASH as a literal. If ethsign's encodeType ever
  # drifts from the contract's own type string, this fails before any
  # signature does.
  type_string <- paste0(
    "Order(uint256 salt,address maker,address signer,uint256 tokenId,",
    "uint256 makerAmount,uint256 takerAmount,uint8 side,uint8 signatureType,",
    "uint256 timestamp,bytes32 metadata,bytes32 builder)"
  )
  expect_equal(
    paste(as.character(keccak256(type_string)), collapse = ""),
    "bb86318a2138f5fa8ae32fbe8e659f8fcf13cc6ae4014a707893055433818589"
  )
})

test_that("eip712_digest reproduces the standard CTF Exchange V2 order digest", {
  # Also equals `hashOrder(order)` read straight off the deployed contract
  # 0xE111180000d2663C0091e4f400237545B87B996B.
  domain <- list(
    name = "Polymarket CTF Exchange",
    version = "2",
    chainId = 137,
    verifyingContract = "0xE111180000d2663C0091e4f400237545B87B996B"
  )
  digest <- eip712_digest(domain, "Order", order_types, order_message)
  expect_equal(
    paste(as.character(digest), collapse = ""),
    "355f1802671f2788e84349ff417cd009b0c5df506ca930f03afb2a6ff7d0471d"
  )
})

test_that("eip712_sign reproduces py-clob-client-v2's Order signature on the standard CTF Exchange V2", {
  domain <- list(
    name = "Polymarket CTF Exchange",
    version = "2",
    chainId = 137,
    verifyingContract = "0xE111180000d2663C0091e4f400237545B87B996B"
  )
  sig <- eip712_sign(eth_signer(testkey), domain, order_types, "Order", order_message)
  expect_match(sig, "^0x[0-9a-f]{130}$")
  expect_equal(
    sig,
    paste0(
      "0xb9f5e224748d09c3b3df516fd6842fc941c8ee21eaf86845763a416e1f77d5a5",
      "7044a9964ac998af5e5a0495a8f393cf1f5502eff225ceed19a063c9c4d58a631b"
    )
  )
})

test_that("eip712_digest reproduces the neg-risk CTF Exchange V2 order digest", {
  # Also equals `hashOrder(order)` read off the deployed neg-risk exchange
  # 0xe2222d279d744050d28e00520010520000310F59.
  domain <- list(
    name = "Polymarket CTF Exchange",
    version = "2",
    chainId = 137,
    verifyingContract = "0xe2222d279d744050d28e00520010520000310F59"
  )
  digest <- eip712_digest(domain, "Order", order_types, order_message)
  expect_equal(
    paste(as.character(digest), collapse = ""),
    "1210e487ae1758da37ebc616c749d937db021fb1d430ad1767c462502ec15223"
  )
})

test_that("eip712_sign reproduces py-clob-client-v2's Order signature on the neg-risk CTF Exchange V2", {
  # Same order fields; only `verifyingContract` differs. A wrong (e.g. swapped
  # or zero-padded) verifyingContract gives a different, wrong signature --
  # this is the independent proof it does not.
  domain <- list(
    name = "Polymarket CTF Exchange",
    version = "2",
    chainId = 137,
    verifyingContract = "0xe2222d279d744050d28e00520010520000310F59"
  )
  sig <- eip712_sign(eth_signer(testkey), domain, order_types, "Order", order_message)
  expect_match(sig, "^0x[0-9a-f]{130}$")
  expect_equal(
    sig,
    paste0(
      "0x498024b023e2b67b8b29716ca46c16183485e16684fb7acaa664e9b0f9906e7b",
      "2a311b7b905b873644c1f811b852f42d27df7cfc843f4d810467f02df0ca8cb41c"
    )
  )
  std_sig <- eip712_sign(
    eth_signer(testkey),
    list(
      name = "Polymarket CTF Exchange",
      version = "2",
      chainId = 137,
      verifyingContract = "0xE111180000d2663C0091e4f400237545B87B996B"
    ),
    order_types,
    "Order",
    order_message
  )
  expect_false(identical(sig, std_sig))
})

test_that("the domain version is hashed: signing the same order under version 1 gives a different signature", {
  # This is the whole 0.2.0 story in one assertion. The domain separator hashes
  # the version STRING, so "1" and "2" are different domains. Everything
  # 0.1.0's vectors certified was certified against a domain the deployed
  # contracts reject.
  v2 <- list(
    name = "Polymarket CTF Exchange",
    version = "2",
    chainId = 137,
    verifyingContract = "0xE111180000d2663C0091e4f400237545B87B996B"
  )
  v1 <- v2
  v1$version <- "1"
  expect_false(identical(
    eip712_sign(eth_signer(testkey), v2, order_types, "Order", order_message),
    eip712_sign(eth_signer(testkey), v1, order_types, "Order", order_message)
  ))
})

# ---- ClobAuth: the three-field domain ---------------------------------------
# name, version, chainId -- NO verifyingContract. Unchanged across the V2
# cutover: py-sdk's `_internal/l1_auth.py` at the commit above still builds
# exactly this domain, and these bytes are identical to 0.1.0's.

test_that("eip712_digest reproduces py-sdk's ClobAuth digest under a three-field domain", {
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
