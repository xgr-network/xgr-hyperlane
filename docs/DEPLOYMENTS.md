# Deployment inventory

Last reconstructed: 2026-09-29  
Primary scope: XGRChain mainnet (chain/domain 1643), Base (chain/domain 8453), XGR interchain/Hyperlane stack, Warp route, and protocol infrastructure repeatedly referenced in this project.

This document was reconstructed from the project conversation history and cross-checked against the repository deployment manifests and current XGR mainnet state where available. It is intended to be the human-readable canonical inventory. Machine-readable manifests under `deployments/` should be kept in sync with it.

## Status vocabulary

- **active** — deployed and currently part of the intended live stack.
- **staged** — deployed and verified, but not yet wired into the live route.
- **fail-closed** — deployed and intentionally configured so traffic cannot pass.
- **external** — dependency deployed by Hyperlane or another upstream project, not by XGR.
- **historical / superseded** — deployed earlier but no longer the canonical deployment set.
- **pending** — planned but not yet deployed.
- **unrecovered** — address or transaction detail was not recoverable from project history.

## Network identities

| Network | Chain ID | Hyperlane domain | RPC |
| --- | ---: | ---: | --- |
| XGRChain Mainnet | 1643 | 1643 | `https://rpc.xgr.network` |
| Base | 8453 | 8453 | external network |

## Canonical operational accounts

| Role | Address | Notes |
| --- | --- | --- |
| Interchain / Warp deployer and router owner | `0x6a6415Aa1c945Ee437336c136c2de9E8baB1F05E` | Foundry account `xgr-base-deployer` on the XGR mainnet deployment host |
| XGR Hyperlane admin owner | `0xE3dA0303c8d48Dd8d4d6f9ba438cD5816b36BBD1` | Recorded project admin/ownership address for the XGR Hyperlane core stack |

Do not commit private keys, keystore passwords, seed phrases, populated env files, or validator secrets.

---

# XGRChain Hyperlane core

Hyperlane Core version recorded in the deployment manifest: **12.1.0**.

| Component | Address | Status | Notes |
| --- | --- | --- | --- |
| Mailbox | `0x5632409bc2f0e8bAc4AaF43654D4FFc7822C9c79` | active | Canonical XGR Hyperlane Mailbox |
| Mailbox implementation | `0xAAFc36b53FdC857429351256447E82f626d47F8a` | active | Implementation behind Mailbox proxy |
| ProxyAdmin | `0xa49AB7f367B6EA25ae1362883F505E2Dc612d1e3` | active | Hyperlane proxy administration |
| StaticMerkleRootMultisigIsmFactory | `0xefBbbe5739662201d66b4B79017c4F6FC4E23896` | active | Factory |
| StaticAggregationIsmFactory | `0xFEBEa0a947349E0aC857F9b7b248f1027804438e` | active | Factory |
| DomainRoutingIsmFactory | `0xfbcE47b2A2Eb371700C6b82bf001d82996C64035` | active | Factory |
| DomainRoutingISM | `0xAf03B407FED3c4857A24Be9ac8EC64b7d178AA51` | active | Base origin 8453 currently routes to the aggregation ISM below |
| MerkleTreeHook | `0xeD98Af715b5a72dCD412567eb086d48225CDDACF` | active | Canonical XGR Hyperlane tree |
| ProtocolFee | `0xf5f7A6D1Bd721D56F016b77e4Fc59C24bE5EA75f` | active | Required hook recorded in project history |
| ValidatorAnnounce | `0x1814Be3E608883cA510707d3dc6f31792FD5CAaF` | active / compatibility | Retained for Hyperlane compatibility/history; not the trust anchor for XGR native BLS finality |

The original core deployment transaction hashes were not consistently preserved in the project chats. The addresses above are the repeatedly confirmed canonical XGR mainnet values.

---

# Base -> XGR fail-closed legacy/prelaunch security on XGR

This is the currently installed Base-origin security path on XGRChain while the native reverse path is being completed.

| Component | Address | Status | Deployment evidence |
| --- | --- | --- | --- |
| PausableISM | `0x1175F84765CFeA514ea1fd75162CFE8a6C64d4CA` | fail-closed | Deploy TX `0x12799252fa4b11f34e71936287a5dea752c22f05cdb51af57427bd293878a371` |
| Base-origin MerkleRootMultisigISM | `0x15Aad8569fe7e6E3E6c6dE3f696bB1eEF7148` | active inside aggregation | Base-origin validator security; project history records 3-of-5 |
| AggregationISM | `0x320e8501677532cc1f5c5bb7990b6db72c627b6c` | active / fail-closed composite | Deploy TX `0xd1f2d50892be7b7fa8ae545654245159ff7d4a2bdf47697358af4aa4c8332313`; threshold 2 |
| DomainRoutingISM update for Base 8453 | `0xAf03B407FED3c4857A24Be9ac8EC64b7d178AA51` | active | Routing update TX `0xede49f09799404f7050cb62ebe0bd08dec52506c1a48dd948428f5419d8b46cc` |

Aggregation modules:

1. `0x1175F84765CFeA514ea1fd75162CFE8a6C64d4CA` — PausableISM
2. `0x15Aad8569fe7e6E3E6c6dE3f696bB1eEF7148` — Base-origin MerkleRootMultisigISM

The PausableISM was last confirmed **paused = true**, therefore the inbound Base -> XGR route remains fail-closed.

Pause transaction recorded in the repository manifest:

`0xc22e1e45ee6dbd990d9e00a6dd82cf3a46e79e63b08d74733d2796fee31364da`

---

# XGR -> Base native BLS destination stack on Base

This is the native XGR-origin security stack deployed on Base.

| Component | Address | Status | Deployment transaction / block |
| --- | --- | --- | --- |
| XGRInterchainBLSVerifier | `0x202C10bDeCf3B796EA4B4025C81952C4F2DD9f93` | active | TX `0xff5615002c089761f6fd4822be328d9f296c3cc7b3459e190da7f8f4923232b8`; Base block 51,565,950 |
| XGRInterchainValidatorRegistry | `0x70F5752326735b31641f21D174BA035E904Db93c` | active | TX `0x5331761a279fd2f187c28439a7b54048f072427f4d0807cb712b88b631883778`; Base block 51,566,144 |
| XGRNativeInterchainISM | `0x3d2aDD3a7dAcb82C11338b6731B22d2aFeD4E1Cc` | active | TX `0x41fdae1ce76c6da393c33f8facdafc4dd1faf469bb88c126be9935833beb5a15`; Base block 51,566,230 |

Last confirmed Base registry state:

- origin chain ID: **1643**
- destination domain: **8453**
- current set ID: **3**
- quorum threshold: **2**
- verifier: `0x202C10bDeCf3B796EA4B4025C81952C4F2DD9f93`

Canonical 3-validator interchain subset, in registry order:

| Index | Validator | Compressed BLS key |
| ---: | --- | --- |
| 0 | `0x98F8bC086454B8386788244eee9A43d5D0b4E63E` | `0xa65579c3b300f0d8e94e77b3915ac09f309c0a109a3aa3bb66d8beb538d733026624bf9d096e2a3d52deff78a36513d1` |
| 1 | `0x7E8f8Fd2A198F77dF298041b48D79b0df4c8B1fa` | `0xa32a09397128b801da5b88319bcca6cc33d4400e12ef7e1a94141b2360abd70306aaeb5599dd0d0984bb02f88fe20b71` |
| 2 | `0x7913fDAe82C678F42B98Ca8076Fe7D13b3EdFF15` | `0xb56b72d028aa6d063d36917f9f18a3ee4b216e22694a701814af4fd55e6cbbe99209fc1359012e4733987ebdd0123e88` |

---

# Warp route

## XGR native router

| Field | Value |
| --- | --- |
| Chain | XGRChain 1643 |
| Contract | XGR native Warp router |
| Address | `0x202C10bDeCf3B796EA4B4025C81952C4F2DD9f93` |
| Owner | `0x6a6415Aa1c945Ee437336c136c2de9E8baB1F05E` |
| Deployment TX | `0x54229bb14d6a46a8f73b40a69e9a1c47b597741fb26b79007ae57e9d87331827` |
| Status | deployed; forward path tested |

## Base synthetic XGR router

| Field | Value |
| --- | --- |
| Chain | Base 8453 |
| Contract | synthetic XGR / wXGR Warp router |
| Address | `0x3b83687d77170d42feddfe221629cc21e771e021` |
| Owner | `0x6a6415Aa1c945Ee437336c136c2de9E8baB1F05E` |
| Deployment TX | unrecovered from project chats |
| Status | deployed; forward path tested |

**Important cross-chain address collision:**  
`0x202C10bDeCf3B796EA4B4025C81952C4F2DD9f93` is the **XGR native Warp router on XGRChain**, but the **BLS verifier on Base**. Always identify the chain together with the address.

## Proven XGR -> Base forward transfer

- XGR dispatch/transfer TX: `0x08671a6c4bc10ab8af4fda602f8d09a393f17212b3e4bf729002c92ce1e50613`
- XGR block: **10,836,602**
- recipient: `0x6a6415Aa1c945Ee437336c136c2de9E8baB1F05E`
- message ID: `0x1b73073ea020bbebbd716a68a58f11a10f8c0d712ccbd38d41ed1dfc53550ad7`
- Base process TX: `0x686e93af92e2a14dee061b33042b62683bd51dcc7069374339d778c54403b90e`
- amount locked on XGR native router: **0.1 XGR**
- amount minted on Base: **0.1 synthetic XGR / wXGR**
- checkpoint index: **3**
- set ID used: **3**

This proves the forward XGR -> Base direction end-to-end. It does **not** mean the public bidirectional bridge is open.

---

# Base -> XGR native V2 stack on XGRChain

## XGRInterchainValidatorRegistryV2

| Field | Value |
| --- | --- |
| Chain | XGRChain Mainnet 1643 |
| Address | `0x013F2F2f7dB897F941b19C4ab71C5395a48A0292` |
| Status | **staged** |
| Deployment TX | `0x0cf70e63929a91ce3940bc1379dcbd2960732e69750152923480b6314f982873` |
| Deployment block | **10,984,538** |
| Deployer | `0x6a6415Aa1c945Ee437336c136c2de9E8baB1F05E` |
| Source branch | `feature/native-interchain-registry-v1` |
| Source commit used | `0b632a3927809f83a3f03456a678fdf8e981d778` |
| originChainId | **1643** |
| destinationDomain | **1643** |
| verifier | `0x0000000000000000000000000000000000002040` |
| verifierKeyFormat | **1 / compressed** |
| minimumDeactivationReserveWei | **1 XGR / validator** |
| maxExecutorReimbursementWei | **0.5 XGR** |
| bootstrap value | **3 XGR** |
| setId | **1** |
| quorumThreshold | **2** |
| set 1 commitment | `0xd033fe96bf990d175beaae337ef327b8de94ca1aa8335b0bccc875bfcb2bff90` |

The deployment transaction succeeded with **4,079,822 gas used**. The constructor verified all three real validator possession proofs through the native XGR BLS precompile `0x2040`; a failed proof would have reverted the deployment.

Bootstrap validator order:

1. `0x98F8bC086454B8386788244eee9A43d5D0b4E63E`
2. `0x7E8f8Fd2A198F77dF298041b48D79b0df4c8B1fa`
3. `0x7913fDAe82C678F42B98Ca8076Fe7D13b3EdFF15`

Each validator was confirmed active with exactly **1 XGR** deactivation reserve.

Historical verification snapshot **set 1** was also read back successfully and matches the bootstrap validator/key order. This is important because V2 intentionally preserves historical sets so a checkpoint signed under set N remains verifiable after a later membership transition.

## XGRNativeInterchainISMV2

| Field | Value |
| --- | --- |
| Chain | XGRChain Mainnet 1643 |
| Address | `0x3b83687d77170D42feDDFe221629cc21e771E021` |
| Status | **staged** |
| Deployment TX | `0x6dbadb839dd1765f86455965a5fa237b73e9221ce77d332c5b60dca88f7c0708` |
| Deployment block | **11,070,512** |
| Gas used | **915,844** |
| Deployer | `0x6a6415Aa1c945Ee437336c136c2de9E8baB1F05E` |
| Registry | `0x013F2F2f7dB897F941b19C4ab71C5395a48A0292` |
| membershipOriginChainId | **1643** via registry |
| checkpointOriginChainId | **8453** |
| originDomain | **8453** |
| originMailbox | `0xeA87ae93Fa0019a82A727bfd3eBd1cFCa8f64f1D` |
| originMerkleTreeHook | `0x19dc38aeae620380430C200a6E990D5Af5480117` |
| destinationDomain | **1643** via registry |
| verifier | `0x0000000000000000000000000000000000002040` via registry |

The V2 contract suite was tested locally before the RegistryV2 deployment:

- **45 tests passed**
- **0 failed**
- **0 skipped**
- includes `testPreviousSetCheckpointRemainsVerifiableAfterMembershipChange()`
- includes `testUnknownHistoricalSetRejected()`

No DomainRoutingISM change has yet been made for this V2 path.

---

## Reverse-path safety aggregation

| Field | Value |
| --- | --- |
| Chain | XGRChain Mainnet 1643 |
| Address | `0x35c2B8403a65D3bd2b86294BF1f26E13A246c05e` |
| Status | **staged / fail-closed** |
| Deployment factory | `0xFEBEa0a947349E0aC857F9b7b248f1027804438e` |
| Deployment TX | `0xdc160be658e85ca4f1c34ee49b1e4e6ad3722f93f886f796f454af70c45e7e67` |
| Deployment block | **11,070,639** |
| Gas used | **108,300** |
| Deployer | `0x6a6415Aa1c945Ee437336c136c2de9E8baB1F05E` |
| Threshold | **2-of-2** |
| Module 0 | PausableISM `0x1175F84765CFeA514ea1fd75162CFE8a6C64d4CA` |
| Module 1 | XGRNativeInterchainISMV2 `0x3b83687d77170D42feDDFe221629cc21e771E021` |

The address was predicted deterministically by the StaticAggregationIsmFactory before deployment. Code was confirmed on-chain at the predicted address. DomainRoutingISM domain 8453 was updated to this aggregation in transaction `0x6f94a1652effdc487bf36ea51c47401536b5a06be64fd6e224cbbb53f897850f` at block **11,070,767**, signed by owner `0xE3dA0303c8d48Dd8d4d6f9ba438cD5816b36BBD1`. Because the PausableISM remains paused, the path remains fail-closed until an intentional unpause.


---

# External Hyperlane contracts on Base

These are external dependencies used by the XGR route. They were not deployed by XGR.

| Component | Address | Status |
| --- | --- | --- |
| Hyperlane Mailbox | `0xeA87ae93Fa0019a82A727bfd3eBd1cFCa8f64f1D` | external |
| MerkleTreeHook | `0x19dc38aeae620380430C200a6E990D5Af5480117` | external |
| ValidatorAnnounce | `0x182E8d7c5F1B06201b102123FC7dF0EaeB445a7B` | external |
| InterchainGasPaymaster | `0xc3F23848Ed2e04C0c6d41bd7804fa8f89F940B94` | external |

---

# XGR node/runtime baseline relevant to interchain

Not a contract deployment, but necessary for interpreting the on-chain stack.

- XGRChain validator runtime: **v3.1.0**
- source commit: `1a4844b311fb856cb8c2303a40fa8aa69b560544`
- all five mainnet validator nodes were confirmed on the same release/build
- native BLS precompile: `0x0000000000000000000000000000000000002040`
- gateway test after rollout: **20/20 successful verifier calls**

The native precompile intentionally has `eth_getCode == 0x`; it is a protocol precompile, not deployed EVM bytecode.

---

# Safe v1.3.0 on XGRChain

The project later performed a canonical Safe v1.3.0 deployment for chain ID 1643 and prepared `safe-global/safe-deployments` PR #1673.

## Canonical September 2026 set

| Safe component | Address | Status |
| --- | --- | --- |
| Safe singleton | `0x69f4D1788e39c87893C980c06EdF4b7f686e2938` | canonical |
| SafeL2 singleton | `0xfb1bffC9d739B8D520DaF37dF666da4C687191EA` | canonical |
| SafeProxyFactory | `0xC22834581EbC8527d974F8a1c97E1bEA4EF910BC` | canonical |
| SimulateTxAccessor | `0x727a77a074D1E6c4530e814F89E618a3298FC044` | canonical |
| DefaultCallbackHandler | `0x3d8E605B02032A941Cfe26897Ca94d77a5BC24b3` | canonical |
| CompatibilityFallbackHandler | `0x017062a1dE2FE6b99BE3d9d37841FeD19F573804` | canonical |
| CreateCall | `0xB19D6FFc2182150F8Eb585b79D4ABcd7C5640A9d` | canonical |
| MultiSend | `0x998739BFdAAdde7C933B942a68053933098f9EDa` | canonical |
| MultiSendCallOnly | `0xA1dabEF33b3B82c7814B6D82A79e50F4AC44102B` | canonical |
| SignMessageLib | `0x98FFBBF51bb33A056B08ddF711f289936AafF717` | canonical |
| Safe Singleton Factory / supporting deployer | `0x914d7Fec6aaC8cd542e72Bca78B30650d45643d7` | supporting infrastructure |

Project record:

- target: Safe **v1.3.0**
- chain ID: **1643**
- Safe deployment registry PR: **#1673**
- title: `Add XGR Mainnet (1643) to Safe v1.3.0 deployments`
- registry validation: **168/168 tests passed**
- PR was still awaiting upstream maintainer merge in the last project check

Individual deployment transaction hashes were not fully reconstructed from the conversation history and should be added later if recovered from the deployment artifacts/explorer.

## Historical February 2026 Safe set

An earlier Safe deployment set also exists on XGRChain. It must not be confused with the canonical September v1.3.0 registry set.

| Historical component | Address | Status |
| --- | --- | --- |
| Safe | `0x35F315F38234e8358B3907C8F26b5f440CEbb53F` | historical / superseded |
| SafeL2 | `0x4Ec97761d6Ead0Ff722b6Ff2c2B0E0A8cAb15219` | historical / superseded |
| SafeMigration | `0x31829A0416018207B857873bD8a2c50Ac8056Cfa` | historical |
| SafeProxyFactory | `0x7375D3D0218aC72d2BB0c912a8094a138b804906` | historical / superseded |
| SimulateTxAccessor | `0x9e260647265aAd33c42589C78dFb661fa99Ab781` | historical / superseded |
| CompatibilityFallbackHandler | `0x339f1c14A4025BAE06575A4b9451DF672b3d1420` | historical / superseded |
| ExtensibleFallbackHandler | `0xA6987346E17fdC538b2f667C4697bd7CAFc6ab59` | historical |
| CreateCall | `0xf5180D0f54286Ae1b7e2519dc03CF7f85D21139d` | historical / superseded |
| MultiSend | `0x2F3B148C3276fD07a672c78094afAFC760C90C8A` | historical / superseded |
| MultiSendCallOnly | `0xd51b8dD910a486f57Bf8095Fe185C3D8829e23CA` | historical / superseded |
| TokenCallbackHandler | `0x584eF0c183A956DeB70480a390E9d5f44e52D864` | historical |
| SignMessageLib | `0x383D8A533C0D23995701190d7A10FE8c3D64f5fD` | historical / superseded |

Do not use this February set as the canonical Safe v1.3.0 deployment inventory.

---

# Other XGR protocol addresses found in project history

| Component | Address | Classification | Notes |
| --- | --- | --- | --- |
| EngineRegistry | `0x72cbbb5c95662510da052b98add933ff99ec820f` | genesis / protocol | Recorded in project history as the configured on-chain source for XGR-specific runtime parameters |

Dynamic XRC-137 / XRC-729 artifacts are intentionally **not** listed as canonical protocol deployments here. The project history contains many user/workflow-specific deployments, and at least one address was only preserved in truncated form. Those belong in an indexed artifact registry rather than this platform deployment inventory.

---

# Known gaps and reconciliation work

1. `deployments/xgr-base-route.json` was reconciled on 2026-10-01 with the deployed routers and reverse V2 security stack.
2. `deployments/xgrchain-mainnet.json` was reconciled on 2026-10-01 with RegistryV2, ISMV2, reverse aggregation and the domain-8453 routing update.
3. Several early Hyperlane-core deployment transaction hashes were not preserved in the project chats.
4. The Base synthetic router deployment transaction hash was not recovered from the project chat history.
5. Safe deployment transaction hashes are incomplete in the project conversation history.
6. XGRNativeInterchainISMV2 was deployed on 2026-10-01 and is wired through the reverse-path aggregation.
7. DomainRoutingISM domain 8453 now points to the V2 reverse-path 2-of-2 aggregation; PausableISM remains paused, so Base -> XGR remains fail-closed.
8. When route/runtime configuration changes, also update the machine-readable manifests in `deployments/`.

---

# Update rule for future deployments

Immediately after every production deployment or configuration transaction, append or update:

- network / chain ID
- contract name and purpose
- contract address
- deployment transaction hash
- deployment block
- deployer
- source repository / branch / commit
- constructor parameters or initialization parameters
- owner / admin / proxy / implementation relationship
- active/staged/fail-closed/superseded status
- replacement relationship if superseded
- material configuration transactions after deployment
- E2E test transaction/message IDs if applicable

Never delete historical addresses. Mark old deployments **historical / superseded** and link them to the replacement.

