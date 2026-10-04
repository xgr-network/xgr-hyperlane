# XGR Interchain Deployment Inventory

Last reviewed: **2026-10-04**

This document is the human-readable deployment inventory for XGR Interchain.

Machine-readable state:

    deployments/xgrchain-mainnet.json
    deployments/xgr-base-route.json

Dynamic operational state must be queried live. Static deployment files record known deployments and test evidence; they do not guarantee that a route is currently enabled for public traffic.

---

## XGRChain Mainnet

| Field | Value |
| --- | --- |
| Chain ID | `1643` |
| Hyperlane domain | `1643` |
| RPC | `https://rpc.xgr.network` |
| Explorer | `https://explorer.xgr.network` |
| Node baseline | `xgr-node v3.1.1` |
| Node release commit | `1a4844b311fb856cb8c2303a40fa8aa69b560544` |

### Hyperlane Core

| Component | Address |
| --- | --- |
| Mailbox | `0x5632409bc2f0e8bAc4AaF43654D4FFc7822C9c79` |
| Mailbox implementation | `0xAAFc36b53FdC857429351256447E82f626d47F8a` |
| ProxyAdmin | `0xa49AB7f367B6EA25ae1362883F505E2Dc612d1e3` |
| StaticMerkleRootMultisigIsmFactory | `0xefBbbe5739662201d66b4B79017c4F6FC4E23896` |
| StaticAggregationIsmFactory | `0xFEBEa0a947349E0aC857F9b7b248f1027804438e` |
| DomainRoutingIsmFactory | `0xfbcE47b2A2Eb371700C6b82bf001d82996C64035` |
| DomainRoutingISM | `0xAf03B407FED3c4857A24Be9ac8EC64b7d178AA51` |
| MerkleTreeHook | `0xeD98Af715b5a72dCD412567eb086d48225CDDACF` |
| ProtocolFee | `0xf5f7A6D1Bd721D56F016b77e4Fc59C24bE5EA75f` |
| ValidatorAnnounce | `0x1814Be3E608883cA510707d3dc6f31792FD5CAaF` |

`ValidatorAnnounce` is deployed Hyperlane infrastructure but is not the trust anchor for XGR-native BLS Interchain security.

---

## Base Mainnet external Hyperlane infrastructure

| Component | Address |
| --- | --- |
| Mailbox | `0xeA87ae93Fa0019a82A727bfd3eBd1cFCa8f64f1D` |
| MerkleTreeHook | `0x19dc38aeae620380430C200a6E990D5Af5480117` |
| ValidatorAnnounce | `0x182E8d7c5F1B06201b102123FC7dF0EaeB445a7B` |
| InterchainGasPaymaster | `0xc3F23848Ed2e04C0c6d41bd7804fa8f89F940B94` |

These are external Hyperlane contracts, not XGRChain consensus components.

---

# XGR → Base native security

The deployed forward path uses the first generation of XGR-native Interchain destination contracts.

V1 means **contract generation**, not legacy Hyperlane validator security.

| Component | Address |
| --- | --- |
| XGRInterchainBLSVerifier | `0x202C10bDeCf3B796EA4B4025C81952C4F2DD9f93` |
| XGRInterchainValidatorRegistry | `0x70F5752326735b31641f21D174BA035E904Db93c` |
| XGRNativeInterchainISM | `0x3d2aDD3a7dAcb82C11338b6731B22d2aFeD4E1Cc` |

Known deployment evidence:

| Component | Deployment TX | Block |
| --- | --- | ---: |
| BLS verifier | `0xff5615002c089761f6fd4822be328d9f296c3cc7b3459e190da7f8f4923232b8` | 51,565,950 |
| Validator registry | `0x5331761a279fd2f187c28439a7b54048f072427f4d0807cb712b88b631883778` | 51,566,144 |
| Native ISM | `0x41fdae1ce76c6da393c33f8facdafc4dd1faf469bb88c126be9935833beb5a15` | 51,566,230 |

Last confirmed forward Interchain set:

    setId = 3
    validators = 3
    quorum = 2

---

# Base → XGR native security

The reverse path uses Registry/ISM V2.

V2 adds historical verification-set snapshots and configurable verifier-key format. It remains the same XGR-native BLS validator security model.

## RegistryV2

| Field | Value |
| --- | --- |
| Address | `0x013F2F2f7dB897F941b19C4ab71C5395a48A0292` |
| Deployment TX | `0x0cf70e63929a91ce3940bc1379dcbd2960732e69750152923480b6314f982873` |
| Deployment block | 10,984,538 |
| setId | 1 |
| validators | 3 |
| quorum | 2 |
| verifier format | compressed |
| verifier | `0x0000000000000000000000000000000000002040` |

Set-1 commitment:

    0xd033fe96bf990d175beaae337ef327b8de94ca1aa8335b0bccc875bfcb2bff90

## XGRNativeInterchainISMV2

| Field | Value |
| --- | --- |
| Address | `0x3b83687d77170D42feDDFe221629cc21e771E021` |
| Deployment TX | `0x6dbadb839dd1765f86455965a5fa237b73e9221ce77d332c5b60dca88f7c0708` |
| Deployment block | 11,070,512 |
| checkpoint origin | Base / 8453 |
| destination | XGRChain / 1643 |
| RegistryV2 | `0x013F2F2f7dB897F941b19C4ab71C5395a48A0292` |

## Reverse aggregation

| Field | Value |
| --- | --- |
| Address | `0x35c2B8403a65D3bd2b86294BF1f26E13A246c05e` |
| Deployment TX | `0xdc160be658e85ca4f1c34ee49b1e4e6ad3722f93f886f796f454af70c45e7e67` |
| Deployment block | 11,070,639 |
| Threshold | 2-of-2 |
| Module 0 | PausableISM `0x1175F84765CFeA514ea1fd75162CFE8a6C64d4CA` |
| Module 1 | XGRNativeInterchainISMV2 `0x3b83687d77170D42feDDFe221629cc21e771E021` |

Domain 8453 routing was updated to the V2 aggregation in:

    0x6f94a1652effdc487bf36ea51c47401536b5a06be64fd6e224cbbb53f897850f

at XGRChain block:

    11,070,767

---

# Warp asset route

## XGRChain native router

    chain:   XGRChain / 1643
    address: 0x202C10bDeCf3B796EA4B4025C81952C4F2DD9f93
    role:    lock / unlock native XGR

Deployment transaction:

    0x54229bb14d6a46a8f73b40a69e9a1c47b597741fb26b79007ae57e9d87331827

## Base synthetic router

    chain:   Base / 8453
    address: 0x3b83687d77170d42feddfe221629cc21e771e021
    role:    mint / burn synthetic XGR / wXGR

The Base router deployment transaction has not been recovered into the repository inventory and remains intentionally unset rather than guessed.

---

# Mainnet E2E evidence

## XGR → Base

Amount:

    0.1 XGR

Origin transaction:

    0x08671a6c4bc10ab8af4fda602f8d09a393f17212b3e4bf729002c92ce1e50613

Origin block:

    10836602

Message ID:

    0x1b73073ea020bbebbd716a68a58f11a10f8c0d712ccbd38d41ed1dfc53550ad7

Base process transaction:

    0x686e93af92e2a14dee061b33042b62683bd51dcc7069374339d778c54403b90e

Checkpoint index:

    3

Set ID:

    3

Result:

    native XGR locked
    synthetic XGR minted

## Base → XGR

Amount:

    0.01 XGR

Base origin transaction:

    0x7a1b61b106e4d631ac599af322cdd7a54510e110ce747076fd934880e27edc89

Message ID:

    0x47919e62a3811e192d5bfe3c1b70f1309675c6d8f8c2b2ee3a439358276c2160

Checkpoint index:

    2184212

Set ID:

    1

XGR destination transaction:

    0x968503696b8a2eebd2c3701fc4c25ef7bde650883e1d81c63a472b0587f333ec

XGR destination block:

    11140781

Gas used:

    461505

Result:

    synthetic XGR burned
    native XGR unlocked

---

# Validator membership scope

Membership is destination-scoped.

Current examples:

    --chain base
        → Base destination registry
        → XGR-origin routes whose destination is Base

    --chain xgr
        → XGRChain destination RegistryV2
        → every configured external-origin route whose destination is XGRChain

Future routes such as `polygon_to_xgr` can therefore reuse the same XGR destination membership while keeping independent route checkpoints and attestations.

---

# Current operational state

The reverse route has passed mainnet E2E validation.

After the controlled reverse test:

    RELAYER_SUBMIT=false
    reverse: STOPPED

During the successful test, the required reverse delivery gates were confirmed open. This document does not assume that dynamic gate state remains unchanged indefinitely.

Always query live state before enabling traffic.

---

# Update rule

After every production deployment or material configuration change, update both machine-readable manifests and this document.

Record:

- chain and domain,
- component,
- address,
- deployment/configuration transaction,
- block where known,
- contract generation,
- current/superseded classification,
- relevant set ID/quorum,
- E2E evidence,
- dynamic-state caveats.

Never invent missing transaction hashes. Use `null` or an explicit unrecovered status until evidence is available.
