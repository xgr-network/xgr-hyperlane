# XGR Interchain Deployment Inventory

**Document ID:** XGR-INTERCHAIN-DEPLOYMENTS  
**Last reviewed:** 2026-10-04  
**Implementation status:** Mainnet  
**Canonical implementation:** `xgr-network/xgr-hyperlane`, branch `main`

This document is the human-readable deployment inventory for the XGR Interchain mainnet infrastructure.

Machine-readable deployment state:

```text
deployments/xgrchain-mainnet.json
deployments/xgr-base-route.json
```

Normalized mainnet records, separate from desired config, are now in:

~~~text
deployments/mainnet/infrastructure/xgrchain.json
deployments/mainnet/infrastructure/base.json
deployments/mainnet/assets/XGR.json
~~~

The old paths above remain authoritative provenance for historical
addresses and E2E transfer evidence. The normalized records are validated
against them by tools/validate-manifests.mjs. ILN v3.1.4 deployment fields
are deliberately null/unverified pending real on-chain deployment and
quorum governance; see docs/MULTI_ASSET_LAYOUT.md.

The current production asset route is:

```text
XGRChain ↔ Base
```

with:

```text
XGRChain: native XGR
Base:     wXGR
```

Both transfer directions are deployed, mainnet-validated and publicly enabled.

Public bridge:

```text
https://bridge.xgr.network
```

Dynamic operational state must still be queried live.

Static deployment files record deployed contracts, configuration relationships, known E2E evidence and observed runtime state. They do not make process health, RPC availability or safety-module state immutable.

---

# 1. Mainnet status

| Component | Status |
| --- | --- |
| XGRChain | Mainnet |
| Base | Mainnet |
| XGRChain Hyperlane-compatible Core | Mainnet |
| Native XGR Interchain node support | Mainnet |
| XGR → Base native security | Mainnet |
| Base → XGR native security | Mainnet |
| Native XGR Warp router | Mainnet |
| Base wXGR router | Mainnet |
| XGR → Base asset transfer | Mainnet / E2E validated / public |
| Base → XGR asset transfer | Mainnet / E2E validated / public |
| Forward relayer | Mainnet / submission enabled |
| Reverse relayer | Mainnet / submission enabled |
| Public XGR Bridge | Mainnet |

The current implementation is not a staged or mixed deployment.

---

# 2. XGRChain Mainnet

| Field | Value |
| --- | --- |
| Network | XGRChain |
| Chain ID | `1643` |
| Hyperlane domain | `1643` |
| RPC | `https://rpc.xgr.network` |
| Explorer | `https://explorer.xgr.network` |
| Native asset | XGR |
| Native decimals | `18` |
| Node baseline | `xgr-node v3.1.1` |
| Node release commit | `1a4844b311fb856cb8c2303a40fa8aa69b560544` |
| Status | Mainnet |

Native BLS12-381 verification precompile:

```text
0x0000000000000000000000000000000000002040
```

---

# 3. XGRChain Hyperlane Core

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

`ValidatorAnnounce` is deployed Hyperlane-compatible infrastructure.

It is not the trust anchor for XGR-native BLS Interchain security.

---

# 4. Base Mainnet

| Field | Value |
| --- | --- |
| Network | Base |
| Chain ID | `8453` |
| Hyperlane domain | `8453` |
| Status | Mainnet |

Reference production RPC used by the XGR Interchain runtime:

```text
https://base-rpc.publicnode.com
```

---

# 5. Base external Hyperlane infrastructure

| Component | Address |
| --- | --- |
| Mailbox | `0xeA87ae93Fa0019a82A727bfd3eBd1cFCa8f64f1D` |
| MerkleTreeHook | `0x19dc38aeae620380430C200a6E990D5Af5480117` |
| ValidatorAnnounce | `0x182E8d7c5F1B06201b102123FC7dF0EaeB445a7B` |
| InterchainGasPaymaster | `0xc3F23848Ed2e04C0c6d41bd7804fa8f89F940B94` |

These contracts are external Hyperlane infrastructure.

They are not XGRChain consensus components.

---

# 6. XGR → Base native security

The deployed forward path uses the first generation of XGR-native Interchain destination contracts.

V1 identifies the contract generation.

It does not mean legacy Hyperlane validator security.

The forward route uses XGR-native BLS validator authorization.

| Component | Address |
| --- | --- |
| XGRInterchainBLSVerifier | `0x202C10bDeCf3B796EA4B4025C81952C4F2DD9f93` |
| XGRInterchainValidatorRegistry | `0x70F5752326735b31641f21D174BA035E904Db93c` |
| XGRNativeInterchainISM | `0x3d2aDD3a7dAcb82C11338b6731B22d2aFeD4E1Cc` |

Known deployment evidence:

| Component | Deployment transaction | Block |
| --- | --- | ---: |
| BLS verifier | `0xff5615002c089761f6fd4822be328d9f296c3cc7b3459e190da7f8f4923232b8` | `51,565,950` |
| Validator registry | `0x5331761a279fd2f187c28439a7b54048f072427f4d0807cb712b88b631883778` | `51,566,144` |
| Native ISM | `0x41fdae1ce76c6da393c33f8facdafc4dd1faf469bb88c126be9935833beb5a15` | `51,566,230` |

Last confirmed forward Interchain set:

```text
setId      = 3
validators = 3
quorum     = 2
```

Current live membership should be read from the deployed registry when operationally relevant.

---

# 7. Base → XGR native security

The reverse path uses Registry/ISM V2.

V2 adds:

- historical validator-set snapshots,
- historical-set verification,
- configurable verifier-key format.

It remains the same XGR-native BLS validator security model.

---

## 7.1 RegistryV2

| Field | Value |
| --- | --- |
| Address | `0x013F2F2f7dB897F941b19C4ab71C5395a48A0292` |
| Deployment transaction | `0x0cf70e63929a91ce3940bc1379dcbd2960732e69750152923480b6314f982873` |
| Deployment block | `10,984,538` |
| setId | `1` |
| Validators | `3` |
| Quorum | `2` |
| Verifier format | `compressed` |
| Verifier | `0x0000000000000000000000000000000000002040` |
| Status | Mainnet |

Set-1 commitment:

```text
0xd033fe96bf990d175beaae337ef327b8de94ca1aa8335b0bccc875bfcb2bff90
```

RegistryV2 preserves historical validator sets so that a checkpoint signed under an earlier valid set can remain verifiable after a membership transition.

---

## 7.2 XGRNativeInterchainISMV2

| Field | Value |
| --- | --- |
| Address | `0x3b83687d77170D42feDDFe221629cc21e771E021` |
| Deployment transaction | `0x6dbadb839dd1765f86455965a5fa237b73e9221ce77d332c5b60dca88f7c0708` |
| Deployment block | `11,070,512` |
| Checkpoint origin | Base / `8453` |
| Destination | XGRChain / `1643` |
| RegistryV2 | `0x013F2F2f7dB897F941b19C4ab71C5395a48A0292` |
| Status | Mainnet |

The ISM verifies compressed BLS aggregate signatures through the native XGRChain BLS precompile:

```text
0x0000000000000000000000000000000000002040
```

---

## 7.3 Reverse aggregation

| Field | Value |
| --- | --- |
| Address | `0x35c2B8403a65D3bd2b86294BF1f26E13A246c05e` |
| Deployment transaction | `0xdc160be658e85ca4f1c34ee49b1e4e6ad3722f93f886f796f454af70c45e7e67` |
| Deployment block | `11,070,639` |
| Threshold | `2-of-2` |
| Status | Mainnet |

Modules:

1. PausableISM

```text
0x1175F84765CFeA514ea1fd75162CFE8a6C64d4CA
```

2. XGRNativeInterchainISMV2

```text
0x3b83687d77170D42feDDFe221629cc21e771E021
```

Both modules must accept the message.

---

## 7.4 Base-domain routing

Base domain:

```text
8453
```

was routed to the V2 AggregationISM through:

```text
0x6f94a1652effdc487bf36ea51c47401536b5a06be64fd6e224cbbb53f897850f
```

at XGRChain block:

```text
11,070,767
```

Destination ISM:

```text
0x35c2B8403a65D3bd2b86294BF1f26E13A246c05e
```

---

# 8. Reverse source confirmation policy

The Base → XGRChain route currently uses:

```text
12 Base blocks
```

of source confirmation before a Base checkpoint becomes eligible for XGR Interchain attestation.

Configured source components:

| Field | Value |
| --- | --- |
| Origin chain | Base |
| Chain ID | `8453` |
| Domain | `8453` |
| Mailbox | `0xeA87ae93Fa0019a82A727bfd3eBd1cFCa8f64f1D` |
| MerkleTreeHook | `0x19dc38aeae620380430C200a6E990D5Af5480117` |
| Confirmation delay | `12` blocks |

This source confirmation policy is separate from XGRChain IBFT finality.

---

# 9. Warp asset route

The production asset model is:

```text
lock → mint
burn → unlock
```

No AMM liquidity is required for the bridge conversion itself.

---

## 9.1 XGRChain native router

```text
chain:   XGRChain / 1643
address: 0x202C10bDeCf3B796EA4B4025C81952C4F2DD9f93
asset:   native XGR
role:    lock / unlock
status:  Mainnet
```

Deployment transaction:

```text
0x54229bb14d6a46a8f73b40a69e9a1c47b597741fb26b79007ae57e9d87331827
```

---

## 9.2 Base wXGR router

```text
chain:   Base / 8453
address: 0x3b83687d77170d42feddfe221629cc21e771e021
asset:   wXGR
role:    mint / burn
status:  Mainnet
```

The Base router is also the official wXGR contract on Base.

The Base router deployment transaction has not been recovered into the repository inventory.

It therefore remains intentionally unset rather than guessed.

Machine-readable representation:

```text
deploymentTx = null
deploymentTxStatus = unrecovered
```

---

## 9.3 Asset representation

Native XGR and wXGR use:

```text
18 decimals
```

Nominal bridge representation:

```text
1 XGR ↔ 1 wXGR
```

before applicable transaction and routing fees.

---

# 10. Important cross-chain address collisions

Contract identity must always include the chain.

The address:

```text
0x202C10bDeCf3B796EA4B4025C81952C4F2DD9f93
```

means:

```text
XGRChain / 1643:
native XGR Warp router

Base / 8453:
XGRInterchainBLSVerifier
```

The address:

```text
0x3b83687d77170d42feDDFe221629cc21e771e021
```

means:

```text
Base / 8453:
official wXGR / synthetic router
```

while the corresponding checksummed address on XGRChain:

```text
0x3b83687d77170D42feDDFe221629cc21e771E021
```

is:

```text
XGRNativeInterchainISMV2
```

Therefore the canonical identity tuple is:

```text
chain + address
```

An address alone is insufficient.

---

# 11. Mainnet E2E evidence

## 11.1 XGR → Base

Amount:

```text
0.1 XGR
```

Origin transaction:

```text
0x08671a6c4bc10ab8af4fda602f8d09a393f17212b3e4bf729002c92ce1e50613
```

Origin block:

```text
10836602
```

Message ID:

```text
0x1b73073ea020bbebbd716a68a58f11a10f8c0d712ccbd38d41ed1dfc53550ad7
```

Base process transaction:

```text
0x686e93af92e2a14dee061b33042b62683bd51dcc7069374339d778c54403b90e
```

Checkpoint index:

```text
3
```

Set ID:

```text
3
```

Result:

```text
native XGR locked
wXGR minted
```

The test verified:

- source lock,
- message dispatch,
- checkpoint creation,
- XGR-native BLS quorum,
- Merkle proof construction,
- destination ISM verification,
- Base Mailbox processing,
- wXGR mint.

---

## 11.2 Base → XGRChain

Amount:

```text
0.01 wXGR
```

Base origin transaction:

```text
0x7a1b61b106e4d631ac599af322cdd7a54510e110ce747076fd934880e27edc89
```

Message ID:

```text
0x47919e62a3811e192d5bfe3c1b70f1309675c6d8f8c2b2ee3a439358276c2160
```

Checkpoint index:

```text
2184212
```

Set ID:

```text
1
```

XGR destination transaction:

```text
0x968503696b8a2eebd2c3701fc4c25ef7bde650883e1d81c63a472b0587f333ec
```

XGR destination block:

```text
11140781
```

Gas used:

```text
461505
```

Result:

```text
wXGR burned
native XGR unlocked
```

The successful destination receipt verified:

- Base wXGR burn,
- Base message dispatch,
- source checkpoint observation,
- configured source confirmation handling,
- reverse BLS quorum,
- compressed BLS verification,
- Merkle inclusion,
- XGR Mailbox processing,
- native XGR unlock.

---

# 12. Validator membership scope

Membership is destination-scoped.

Current examples:

```text
--chain base
    ↓
Base destination registry
    ↓
XGR-origin routes whose destination is Base
```

and:

```text
--chain xgr
    ↓
XGRChain destination RegistryV2
    ↓
configured external-origin routes whose destination is XGRChain
```

For example, future routes such as:

```text
polygon_to_xgr
arbitrum_to_xgr
```

can reuse the same XGR destination registry membership while retaining independent:

- source chains,
- Mailboxes,
- MerkleTreeHooks,
- confirmation policies,
- checkpoint streams,
- attestations.

Therefore:

```text
membership scope = destination
checkpoint scope = route
```

---

# 13. Consensus and Interchain authority

XGRChain consensus and XGR Interchain authorization are separate security domains.

```text
XGRChain consensus
≠
XGR Interchain validator quorum
```

XGRChain consensus uses:

- IBFT,
- delegated PoS,
- stake-weighted voting power,
- uptime weighting.

XGR Interchain uses:

- destination-specific validator membership,
- BLS checkpoint attestations,
- an unweighted two-thirds Interchain quorum.

The current three-validator Interchain set therefore uses:

```text
quorum = 2
```

This must not be confused with XGRChain's weighted IBFT quorum calculation.

---

# 14. Current operational state

At the current documentation baseline:

```text
observed date = 2026-10-04
```

both directions are enabled for production use.

---

## 14.1 Forward

```text
route:             XGRChain → Base
attestation route: base
signature format:  eip2537
RELAYER_SUBMIT:    true
process:           RUNNING
public:            enabled
status:            Mainnet
```

---

## 14.2 Reverse

```text
route:             Base → XGRChain
attestation route: base_to_xgr
signature format:  compressed
RELAYER_SUBMIT:    true
process:           RUNNING
public:            enabled
status:            Mainnet
```

Reverse origin RPC:

```text
https://base-rpc.publicnode.com
```

---

## 14.3 Reverse delivery gates

The current production reverse route requires:

```text
Base synthetic router outbound enabled
XGR native router inbound enabled
PausableISM not paused
DomainRoutingISM mapped to V2 AggregationISM
valid RegistryV2 set
valid BLS quorum
reverse relayer submission enabled
reverse relayer process available
```

The latest observed production state has these required route gates open.

These values remain dynamic operational properties.

They must be queried live when current availability is material.

---

# 15. Public bridge

The XGRChain ↔ Base route is exposed through the production bridge:

```text
https://bridge.xgr.network
```

Current supported directions:

```text
XGR → wXGR
wXGR → XGR
```

The source transaction is signed by the user's own wallet.

The native relayer does not possess the user's wallet private key.

The relayer provides destination transaction submission and delivery availability.

It is not the cryptographic trust anchor for message validity.

---

# 16. Relayer trust model

The relayer:

- indexes dispatched messages,
- reconstructs Merkle proofs,
- retrieves completed native attestations,
- checks proof roots locally,
- constructs destination metadata,
- pays destination gas,
- submits `Mailbox.process()`.

The relayer cannot independently create:

- validator registry membership,
- a valid BLS quorum,
- a valid aggregate signature,
- a valid Merkle inclusion proof for a message outside the committed tree.

Therefore compromise of the relayer gas key does not by itself provide Interchain validator authority.

---

# 17. Dynamic state versus deployment state

The following are static deployment facts:

- contract addresses,
- deployment transactions,
- deployment blocks,
- route architecture,
- security-module relationships,
- historical E2E evidence.

The following are dynamic operational facts:

- router enable flags,
- PausableISM state,
- current registry membership,
- current attestation production,
- RPC availability,
- relayer process state,
- `RELAYER_SUBMIT`,
- relayer gas balance,
- pending message backlog.

Therefore:

```text
deployed
```

does not automatically mean:

```text
currently healthy
```

and:

```text
E2E validated
```

does not mean:

```text
infrastructure can never become temporarily unavailable
```

At the current baseline, however, the production route is deployed and publicly enabled in both directions.

---

# 18. Source-of-truth hierarchy

For deployed XGR Interchain state:

1. live on-chain contract state,
2. active runtime state,
3. machine-readable deployment manifests,
4. human-readable deployment documentation.

Machine-readable inventory:

```text
deployments/xgrchain-mainnet.json
deployments/xgr-base-route.json
```

Human-readable inventory:

```text
docs/DEPLOYMENTS.md
```

Public protocol specification:

```text
https://github.com/xgr-network/XGR/tree/main/docs/interchain
```

Implementation and runtime:

```text
https://github.com/xgr-network/xgr-hyperlane
```

A stale static document must never override verified live state.

---

# 19. Update rule

After every production deployment or material configuration change, update both the machine-readable manifests and this document.

Record where applicable:

- network,
- chain ID,
- domain,
- component,
- address,
- deployment transaction,
- deployment block,
- contract generation,
- source branch/commit,
- current or superseded classification,
- validator set ID,
- validator count,
- quorum,
- verifier format,
- routing configuration,
- E2E evidence,
- route-direction state.

Dynamic process status should be recorded only as an observed state with an observation date.

Do not invent missing transaction hashes.

Use:

```text
null
```

or an explicit:

```text
unrecovered
```

status until evidence is available.

Do not delete superseded deployment history.

Mark superseded components explicitly as historical.

---

# 20. Current production summary

```text
XGRChain / 1643
    │
    │ native XGR
    │
    ▼
XGR native Warp router
    │
    ▼
XGR Hyperlane-compatible Mailbox
    │
    ▼
XGR-native BLS attestation
    │
    ▼
native relayer
    │
    ▼
Base Mailbox
    │
    ▼
XGR-native destination security
    │
    ▼
Base wXGR router
    │
    ▼
wXGR
```

Reverse:

```text
wXGR
    │
    ▼
Base wXGR router
    │
    ▼
Base Mailbox / MerkleTreeHook
    │
    ▼
confirmed Base checkpoint
    │
    ▼
XGR base_to_xgr BLS quorum
    │
    ▼
reverse native relayer
    │
    ▼
XGR Mailbox
    │
    ▼
DomainRoutingISM
    │
    ▼
2-of-2 AggregationISM
    ├── PausableISM
    └── XGRNativeInterchainISMV2
              │
              ▼
       native BLS precompile
              │
              ▼
XGR native Warp router
    │
    ▼
native XGR
```

Current status:

```text
Implementation status: Mainnet

XGRChain → Base:
    deployed
    E2E validated
    relayer submission enabled
    relayer running
    publicly available

Base → XGRChain:
    deployed
    E2E validated
    relayer submission enabled
    relayer running
    publicly available

Public bridge:
    https://bridge.xgr.network
```
